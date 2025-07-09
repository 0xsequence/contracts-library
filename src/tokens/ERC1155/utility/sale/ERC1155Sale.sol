// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { MerkleProofSingleUse } from "../../../common/MerkleProofSingleUse.sol";
import { SignalsImplicitModeControlled } from "../../../common/SignalsImplicitModeControlled.sol";
import { AccessControlEnumerable, IERC20, SafeERC20, WithdrawControlled } from "../../../common/WithdrawControlled.sol";
import { IERC1155ItemsFunctions } from "../../presets/items/IERC1155Items.sol";
import { IERC1155Sale, IERC1155SaleFunctions } from "./IERC1155Sale.sol";

contract ERC1155Sale is IERC1155Sale, WithdrawControlled, MerkleProofSingleUse, SignalsImplicitModeControlled {

    bytes32 internal constant MINT_ADMIN_ROLE = keccak256("MINT_ADMIN_ROLE");

    bool private _initialized;
    address private _items;

    // ERC20 token address for payment. address(0) indicated payment in ETH.
    address private _paymentToken;

    GlobalSaleDetails private _globalSaleDetails;
    mapping(uint256 => SaleDetails) private _tokenSaleDetails;

    /**
     * Initialize the contract.
     * @param owner Owner address
     * @param items The ERC-1155 Items contract address
     * @param implicitModeValidator Implicit session validator address
     * @param implicitModeProjectId Implicit session project id
     * @dev This should be called immediately after deployment.
     */
    function initialize(
        address owner,
        address items,
        address implicitModeValidator,
        bytes32 implicitModeProjectId
    ) public virtual {
        if (_initialized) {
            revert InvalidInitialization();
        }

        _items = items;

        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(MINT_ADMIN_ROLE, owner);
        _grantRole(WITHDRAW_ROLE, owner);

        _initializeImplicitMode(owner, implicitModeValidator, implicitModeProjectId);

        _initialized = true;
    }

    /**
     * Checks if the current block.timestamp is out of the give timestamp range.
     * @param _startTime Earliest acceptable timestamp (inclusive).
     * @param _endTime Latest acceptable timestamp (exclusive).
     * @dev A zero endTime value is always considered out of bounds.
     */
    function _blockTimeOutOfBounds(uint256 _startTime, uint256 _endTime) private view returns (bool) {
        // 0 end time indicates inactive sale.
        return _endTime == 0 || block.timestamp < _startTime || block.timestamp >= _endTime; // solhint-disable-line not-rely-on-time
    }

    /**
     * Checks the sale is active, valid and takes payment.
     * @param _tokenIds Token IDs to mint.
     * @param _amounts Amounts of tokens to mint.
     * @param _expectedPaymentToken ERC20 token address to accept payment in. address(0) indicates ETH.
     * @param _maxTotal Maximum amount of payment tokens.
     * @param _proof Merkle proof for allowlist minting.
     */
    function _validateMint(
        uint256[] memory _tokenIds,
        uint256[] memory _amounts,
        address _expectedPaymentToken,
        uint256 _maxTotal,
        bytes32[] calldata _proof
    ) private {
        uint256 lastTokenId;
        uint256 totalCost;
        uint256 totalAmount;

        GlobalSaleDetails memory gSaleDetails = _globalSaleDetails;
        bool globalSaleInactive = _blockTimeOutOfBounds(gSaleDetails.startTime, gSaleDetails.endTime);
        bool globalMerkleCheckRequired = false;
        for (uint256 i; i < _tokenIds.length; i++) {
            uint256 tokenId = _tokenIds[i];
            // Test tokenIds ordering
            if (i != 0 && lastTokenId >= tokenId) {
                revert InvalidTokenIds();
            }
            lastTokenId = tokenId;

            uint256 amount = _amounts[i];

            // Active sale test
            SaleDetails memory saleDetails = _tokenSaleDetails[tokenId];
            bool tokenSaleInactive = _blockTimeOutOfBounds(saleDetails.startTime, saleDetails.endTime);
            if (tokenSaleInactive) {
                // Prefer token sale
                if (gSaleDetails.minTokenId > tokenId || gSaleDetails.maxTokenId < tokenId || globalSaleInactive) {
                    // Both sales inactive
                    revert SaleInactive(tokenId);
                }
                // Use global sale details
                if (_globalSaleDetails.remainingSupply < amount) {
                    revert InsufficientSupply(_globalSaleDetails.remainingSupply, amount);
                }
                globalMerkleCheckRequired = true;
                totalCost += gSaleDetails.cost * amount;
                _globalSaleDetails.remainingSupply -= amount;
            } else {
                // Use token sale details
                if (saleDetails.remainingSupply < amount) {
                    revert InsufficientSupply(saleDetails.remainingSupply, amount);
                }
                requireMerkleProof(saleDetails.merkleRoot, _proof, msg.sender, bytes32(tokenId));
                totalCost += saleDetails.cost * amount;
                _tokenSaleDetails[tokenId].remainingSupply -= amount;
            }
            totalAmount += amount;
        }

        if (globalMerkleCheckRequired) {
            // Check it once outside the loop only when required
            requireMerkleProof(gSaleDetails.merkleRoot, _proof, msg.sender, bytes32(type(uint256).max));
        }

        if (_expectedPaymentToken != _paymentToken) {
            // Caller expected different payment token
            revert InsufficientPayment(_paymentToken, totalCost, 0);
        }
        if (_maxTotal < totalCost) {
            // Caller expected to pay less
            revert InsufficientPayment(_expectedPaymentToken, totalCost, _maxTotal);
        }
        if (_expectedPaymentToken == address(0)) {
            // Paid in ETH
            if (msg.value != totalCost) {
                // We expect exact value match
                revert InsufficientPayment(_expectedPaymentToken, totalCost, msg.value);
            }
        } else if (msg.value > 0) {
            // Paid in ERC20, but sent ETH
            revert InsufficientPayment(address(0), 0, msg.value);
        } else {
            // Paid in ERC20
            SafeERC20.safeTransferFrom(IERC20(_expectedPaymentToken), msg.sender, address(this), totalCost);
        }
    }

    //
    // Minting
    //

    /**
     * Mint tokens.
     * @param to Address to mint tokens to.
     * @param tokenIds Token IDs to mint.
     * @param amounts Amounts of tokens to mint.
     * @param data Data to pass if receiver is contract.
     * @param expectedPaymentToken ERC20 token address to accept payment in. address(0) indicates ETH.
     * @param maxTotal Maximum amount of payment tokens.
     * @param proof Merkle proof for allowlist minting.
     * @notice Sale must be active for all tokens.
     * @dev tokenIds must be sorted ascending without duplicates.
     * @dev An empty proof is supplied when no proof is required.
     */
    function mint(
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts,
        bytes memory data,
        address expectedPaymentToken,
        uint256 maxTotal,
        bytes32[] calldata proof
    ) public payable {
        if (tokenIds.length != amounts.length) {
            revert InvalidTokenIds();
        }
        _validateMint(tokenIds, amounts, expectedPaymentToken, maxTotal, proof);
        IERC1155ItemsFunctions(_items).batchMint(to, tokenIds, amounts, data);
        emit ItemsMinted(to, tokenIds, amounts);
    }

    //
    // Admin
    //

    /**
     * Set the payment token.
     * @param paymentTokenAddr The ERC20 token address to accept payment in. address(0) indicates ETH.
     * @dev This should be set before the sale starts.
     */
    function setPaymentToken(
        address paymentTokenAddr
    ) public onlyRole(MINT_ADMIN_ROLE) {
        _paymentToken = paymentTokenAddr;
    }

    /**
     * Set the global sale details.
     * @param minTokenId The minimum token ID to apply the sale to.
     * @param maxTokenId The maximum token ID to apply the sale to.
     * @param cost The amount of payment tokens to accept for each token minted.
     * @param remainingSupply The maximum number of tokens that can be minted by the items contract.
     * @param startTime The start time of the sale. Tokens cannot be minted before this time.
     * @param endTime The end time of the sale. Tokens cannot be minted after this time.
     * @param merkleRoot The merkle root for allowlist minting.
     * @dev A zero end time indicates an inactive sale.
     * @notice The payment token is set globally.
     */
    function setGlobalSaleDetails(
        uint256 minTokenId,
        uint256 maxTokenId,
        uint256 cost,
        uint256 remainingSupply,
        uint64 startTime,
        uint64 endTime,
        bytes32 merkleRoot
    ) public onlyRole(MINT_ADMIN_ROLE) {
        // solhint-disable-next-line not-rely-on-time
        if (endTime < startTime || endTime <= block.timestamp) {
            revert InvalidSaleDetails();
        }
        if (remainingSupply == 0) {
            revert InvalidSaleDetails();
        }
        _globalSaleDetails =
            GlobalSaleDetails(minTokenId, maxTokenId, cost, remainingSupply, startTime, endTime, merkleRoot);
        emit GlobalSaleDetailsUpdated(minTokenId, maxTokenId, cost, remainingSupply, startTime, endTime, merkleRoot);
    }

    /**
     * Set the sale details for an individual token.
     * @param tokenId The token ID to set the sale details for.
     * @param cost The amount of payment tokens to accept for each token minted.
     * @param remainingSupply The maximum number of tokens that can be minted by this contract.
     * @param startTime The start time of the sale. Tokens cannot be minted before this time.
     * @param endTime The end time of the sale. Tokens cannot be minted after this time.
     * @param merkleRoot The merkle root for allowlist minting.
     * @dev A zero end time indicates an inactive sale.
     * @notice The payment token is set globally.
     */
    function setTokenSaleDetails(
        uint256 tokenId,
        uint256 cost,
        uint256 remainingSupply,
        uint64 startTime,
        uint64 endTime,
        bytes32 merkleRoot
    ) public onlyRole(MINT_ADMIN_ROLE) {
        // solhint-disable-next-line not-rely-on-time
        if (endTime < startTime || endTime <= block.timestamp) {
            revert InvalidSaleDetails();
        }
        if (remainingSupply == 0) {
            revert InvalidSaleDetails();
        }
        _tokenSaleDetails[tokenId] = SaleDetails(cost, remainingSupply, startTime, endTime, merkleRoot);
        emit TokenSaleDetailsUpdated(tokenId, cost, remainingSupply, startTime, endTime, merkleRoot);
    }

    /**
     * Set the sale details for a batch of tokens.
     * @param tokenIds The token IDs to set the sale details for.
     * @param costs The amount of payment tokens to accept for each token minted.
     * @param remainingSupplies The maximum number of tokens that can be minted by this contract.
     * @param startTimes The start time of the sale. Tokens cannot be minted before this time.
     * @param endTimes The end time of the sale. Tokens cannot be minted after this time.
     * @param merkleRoots The merkle root for allowlist minting.
     * @dev A zero end time indicates an inactive sale.
     * @notice The payment token is set globally.
     * @dev tokenIds must be sorted ascending without duplicates.
     */
    function setTokenSaleDetailsBatch(
        uint256[] calldata tokenIds,
        uint256[] calldata costs,
        uint256[] calldata remainingSupplies,
        uint64[] calldata startTimes,
        uint64[] calldata endTimes,
        bytes32[] calldata merkleRoots
    ) public onlyRole(MINT_ADMIN_ROLE) {
        if (
            tokenIds.length != costs.length || tokenIds.length != remainingSupplies.length
                || tokenIds.length != startTimes.length || tokenIds.length != endTimes.length
                || tokenIds.length != merkleRoots.length
        ) {
            revert InvalidSaleDetails();
        }

        uint256 lastTokenId;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            if (i != 0 && lastTokenId >= tokenId) {
                revert InvalidTokenIds();
            }
            lastTokenId = tokenId;

            // solhint-disable-next-line not-rely-on-time
            if (endTimes[i] < startTimes[i] || endTimes[i] <= block.timestamp) {
                revert InvalidSaleDetails();
            }
            if (remainingSupplies[i] == 0) {
                revert InvalidSaleDetails();
            }
            _tokenSaleDetails[tokenId] =
                SaleDetails(costs[i], remainingSupplies[i], startTimes[i], endTimes[i], merkleRoots[i]);
            emit TokenSaleDetailsUpdated(
                tokenId, costs[i], remainingSupplies[i], startTimes[i], endTimes[i], merkleRoots[i]
            );
        }
    }

    //
    // Views
    //

    /**
     * Get global sales details.
     * @return Sale details.
     * @notice Global sales details apply to all tokens.
     * @notice Global sales details are overriden when token sale is active.
     */
    function globalSaleDetails() external view returns (GlobalSaleDetails memory) {
        return _globalSaleDetails;
    }

    /**
     * Get token sale details.
     * @param tokenId Token ID to get sale details for.
     * @return Sale details.
     * @notice Token sale details override global sale details.
     */
    function tokenSaleDetails(
        uint256 tokenId
    ) external view returns (SaleDetails memory) {
        return _tokenSaleDetails[tokenId];
    }

    /**
     * Get sale details for multiple tokens.
     * @param tokenIds Array of token IDs to retrieve sale details for.
     * @return Array of sale details corresponding to each token ID.
     * @notice Each token's sale details override the global sale details if set.
     */
    function tokenSaleDetailsBatch(
        uint256[] calldata tokenIds
    ) external view returns (SaleDetails[] memory) {
        SaleDetails[] memory details = new SaleDetails[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            details[i] = _tokenSaleDetails[tokenIds[i]];
        }
        return details;
    }

    /**
     * Get payment token.
     * @return Payment token address.
     * @notice address(0) indicates payment in ETH.
     */
    function paymentToken() external view returns (address) {
        return _paymentToken;
    }

    /**
     * Check interface support.
     * @param interfaceId Interface id
     * @return True if supported
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(WithdrawControlled, SignalsImplicitModeControlled) returns (bool) {
        return type(IERC1155SaleFunctions).interfaceId == interfaceId
            || WithdrawControlled.supportsInterface(interfaceId)
            || SignalsImplicitModeControlled.supportsInterface(interfaceId);
    }

}
