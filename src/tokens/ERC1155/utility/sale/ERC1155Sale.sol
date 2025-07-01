// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { MerkleProofSingleUse } from "../../../common/MerkleProofSingleUse.sol";
import { SignalsImplicitModeControlled } from "../../../common/SignalsImplicitModeControlled.sol";
import { AccessControlEnumerable, IERC20, SafeERC20, WithdrawControlled } from "../../../common/WithdrawControlled.sol";
import { IERC1155ItemsFunctions } from "../../presets/items/IERC1155Items.sol";
import { IERC1155Sale } from "./IERC1155Sale.sol";

contract ERC1155Sale is IERC1155Sale, WithdrawControlled, MerkleProofSingleUse, SignalsImplicitModeControlled {

    bytes32 internal constant MINT_ADMIN_ROLE = keccak256("MINT_ADMIN_ROLE");

    bool private _initialized;
    address private _items;

    // Sales details indexed by sale index.
    SaleDetails[] private _saleDetails;
    // tokenId => saleIndex => quantity minted
    mapping(uint256 => mapping(uint256 => uint256)) private _tokensMintedPerSale;

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
     * Checks the sale is active, valid and takes payment.
     * @param _tokenIds Token IDs to mint.
     * @param _amounts Amounts of tokens to mint.
     * @param _saleIndexes Sale indexes for each token.
     * @param _expectedPaymentToken ERC20 token address to accept payment in. address(0) indicates ETH.
     * @param _maxTotal Maximum amount of payment tokens.
     * @param _proofs Merkle proofs for allowlist minting.
     */
    function _validateMint(
        uint256[] calldata _tokenIds,
        uint256[] calldata _amounts,
        uint256[] calldata _saleIndexes,
        address _expectedPaymentToken,
        uint256 _maxTotal,
        bytes32[][] calldata _proofs
    ) private {
        uint256 totalCost;

        // Validate input arrays have matching lengths
        uint256 length = _tokenIds.length;
        if (length != _amounts.length || length != _saleIndexes.length || length != _proofs.length) {
            revert InvalidArrayLengths();
        }

        for (uint256 i; i < length; i++) {
            uint256 tokenId = _tokenIds[i];
            uint256 saleIndex = _saleIndexes[i];

            // Find the sale details for the token
            if (saleIndex >= _saleDetails.length) {
                revert SaleDetailsNotFound(saleIndex);
            }
            SaleDetails memory details = _saleDetails[saleIndex];

            // Check if token is within the sale range
            if (tokenId < details.minTokenId || tokenId > details.maxTokenId) {
                revert InvalidSaleDetails();
            }

            // Check if sale is active
            // solhint-disable-next-line not-rely-on-time
            if (block.timestamp < details.startTime || block.timestamp > details.endTime) {
                revert SaleInactive();
            }

            // Validate payment token matches expected
            if (details.paymentToken != _expectedPaymentToken) {
                revert PaymentTokenMismatch();
            }

            uint256 amount = _amounts[i];
            if (amount == 0) {
                revert InvalidAmount();
            }

            // Check supply
            uint256 minted = _tokensMintedPerSale[tokenId][saleIndex];
            if (amount > details.supply - minted) {
                revert InsufficientSupply(details.supply - minted, amount);
            }

            // Check merkle proof
            requireMerkleProof(details.merkleRoot, _proofs[i], msg.sender, bytes32(tokenId));

            // Update supply and calculate cost
            _tokensMintedPerSale[tokenId][saleIndex] = minted + amount;
            totalCost += details.cost * amount;
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

    /// @inheritdoc IERC1155Sale
    /// @notice Sale must be active for all tokens.
    /// @dev All sales must use the same payment token.
    /// @dev An empty proof is supplied when no proof is required.
    function mint(
        address to,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts,
        bytes calldata data,
        uint256[] calldata saleIndexes,
        address expectedPaymentToken,
        uint256 maxTotal,
        bytes32[][] calldata proofs
    ) public payable {
        _validateMint(tokenIds, amounts, saleIndexes, expectedPaymentToken, maxTotal, proofs);
        IERC1155ItemsFunctions(_items).batchMint(to, tokenIds, amounts, data);
        emit ItemsMinted(to, tokenIds, amounts, saleIndexes);
    }

    //
    // Admin
    //

    /// @inheritdoc IERC1155Sale
    function addSaleDetails(
        SaleDetails calldata details
    ) public onlyRole(MINT_ADMIN_ROLE) returns (uint256 saleIndex) {
        _validateSaleDetails(details);

        saleIndex = _saleDetails.length;
        _saleDetails.push(details);

        emit SaleDetailsAdded(saleIndex, details);
    }

    /// @inheritdoc IERC1155Sale
    function updateSaleDetails(uint256 saleIndex, SaleDetails calldata details) public onlyRole(MINT_ADMIN_ROLE) {
        if (saleIndex >= _saleDetails.length) {
            revert SaleDetailsNotFound(saleIndex);
        }
        _validateSaleDetails(details);

        _saleDetails[saleIndex] = details;

        emit SaleDetailsUpdated(saleIndex, details);
    }

    function _validateSaleDetails(
        SaleDetails calldata details
    ) private pure {
        if (details.maxTokenId < details.minTokenId) {
            revert InvalidSaleDetails();
        }
        if (details.supply == 0) {
            revert InvalidSaleDetails();
        }
        if (details.endTime < details.startTime) {
            revert InvalidSaleDetails();
        }
    }

    //
    // Views
    //

    /// @inheritdoc IERC1155Sale
    function saleDetailsCount() external view returns (uint256) {
        return _saleDetails.length;
    }

    /// @inheritdoc IERC1155Sale
    function saleDetails(
        uint256 saleIndex
    ) external view returns (SaleDetails memory) {
        if (saleIndex >= _saleDetails.length) {
            revert SaleDetailsNotFound(saleIndex);
        }
        return _saleDetails[saleIndex];
    }

    /// @inheritdoc IERC1155Sale
    function saleDetailsBatch(
        uint256[] calldata saleIndexes
    ) external view returns (SaleDetails[] memory) {
        SaleDetails[] memory details = new SaleDetails[](saleIndexes.length);
        for (uint256 i = 0; i < saleIndexes.length; i++) {
            if (saleIndexes[i] >= _saleDetails.length) {
                revert SaleDetailsNotFound(saleIndexes[i]);
            }
            details[i] = _saleDetails[saleIndexes[i]];
        }
        return details;
    }

    /**
     * Check interface support.
     * @param interfaceId Interface id
     * @return True if supported
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(WithdrawControlled, SignalsImplicitModeControlled) returns (bool) {
        return type(IERC1155Sale).interfaceId == interfaceId || WithdrawControlled.supportsInterface(interfaceId)
            || SignalsImplicitModeControlled.supportsInterface(interfaceId);
    }

}
