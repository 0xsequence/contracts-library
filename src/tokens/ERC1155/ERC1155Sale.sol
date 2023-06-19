// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {IERC1155Sale} from "./IERC1155Sale.sol";
import {ERC1155Supply, ERC1155Token} from "./ERC1155Supply.sol";
import {ERC1155SaleErrors} from "./ERC1155SaleErrors.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC1155Sale is
    IERC1155Sale,
    ERC1155SaleErrors,
    ERC1155Supply
{
    bytes32 public constant MINT_ADMIN_ROLE = keccak256("MINT_ADMIN_ROLE");

    bytes4 private constant ERC20_TRANSFERFROM_SELECTOR =
        bytes4(keccak256(bytes("transferFrom(address,address,uint256)")));

    bool private _initialized;

    // ERC20 token address for payment. address(0) indicated payment in ETH.
    address private _paymentToken;

    SaleDetails private _globalSaleDetails;
    mapping(uint256 => SaleDetails) private _tokenSaleDetails;

    /**
     * Initialize the contract.
     * @param _owner Owner address.
     * @param _name Token name.
     * @param _baseURI Base URI for token metadata.
     * @dev This should be called immediately after deployment.
     */
    function initialize(address _owner, string memory _name, string memory _baseURI) public {
        if (_initialized) {
            revert InvalidInitialization();
        }
        ERC1155Token._initialize(_owner, _name, _baseURI);

        name = _name;
        baseURI = _baseURI;
        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        _setupRole(MINT_ADMIN_ROLE, _owner);
        _initialized = true;
    }

    /**
     * Checks if the current block.timestamp is out of the give timestamp range.
     * @param startTime Earliest acceptable timestamp (inclusive).
     * @param endTime Latest acceptable timestamp (exclusive).
     * @dev A zero endTime value is always considered out of bounds.
     */
    function blockTimeOutOfBounds(uint256 startTime, uint256 endTime) private view returns (bool) {
        // 0 end time indicates inactive sale.
        return endTime == 0 || block.timestamp < startTime || block.timestamp >= endTime; // solhint-disable-line not-rely-on-time
    }

    /**
     * Checks the sale is active and takes payment.
     * @param _tokenIds Token IDs to mint.
     * @param _amounts Amounts of tokens to mint.
     */
    function payForActiveMint(uint256[] memory _tokenIds, uint256[] memory _amounts) private {
        uint256 lastTokenId;
        uint256 totalCost;
        uint256 totalAmount;

        SaleDetails memory gSaleDetails = _globalSaleDetails;
        bool globalSaleInactive = blockTimeOutOfBounds(gSaleDetails.startTime, gSaleDetails.endTime);
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
            bool tokenSaleInactive = blockTimeOutOfBounds(saleDetails.startTime, saleDetails.endTime);
            if (tokenSaleInactive) {
                // Prefer token sale
                if (globalSaleInactive) {
                    // Both sales inactive
                    revert SaleInactive(tokenId);
                }
                // Use global sale details
                totalCost += gSaleDetails.cost * amount;
            } else {
                // Use token sale price
                totalCost += saleDetails.cost * amount;
            }
            totalAmount += amount;
        }

        if (_paymentToken == address(0)) {
            // Paid in ETH
            if (msg.value != totalCost) {
                revert InsufficientPayment(totalCost, msg.value);
            }
        } else {
            // Paid in ERC20
            (bool success, bytes memory data) = _paymentToken.call(
                abi.encodeWithSelector(ERC20_TRANSFERFROM_SELECTOR, msg.sender, address(this), totalCost)
            );
            if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
                revert InsufficientPayment(totalCost, 0);
            }
        }
    }

    //
    // Minting
    //

    /**
     * Mint tokens.
     * @param _to Address to mint tokens to.
     * @param _tokenIds Token IDs to mint.
     * @param _amounts Amounts of tokens to mint.
     * @param _data Data to pass if receiver is contract.
     * @notice Sale must be active for all tokens.
     * @dev tokenIds must be sorted ascending without duplicates.
     */
    function mint(address _to, uint256[] memory _tokenIds, uint256[] memory _amounts, bytes memory _data)
        public
        payable
    {
        payForActiveMint(_tokenIds, _amounts);
        _batchMint(_to, _tokenIds, _amounts, _data);
    }

    /**
     * Mint tokens as admin.
     * @param _to Address to mint tokens to.
     * @param _tokenIds Token IDs to mint.
     * @param _amounts Amounts of tokens to mint.
     * @param _data Data to pass if receiver is contract.
     * @notice Only callable by mint admin.
     */
    function mintAdmin(address _to, uint256[] memory _tokenIds, uint256[] memory _amounts, bytes memory _data)
        public
        onlyRole(MINT_ADMIN_ROLE)
    {
        _batchMint(_to, _tokenIds, _amounts, _data);
    }

    /**
     * Set the global sale details.
     * @param _paymentTokenAddr The ERC20 token address to accept payment in. address(0) indicates ETH.
     * @param _cost The amount of payment tokens to accept for each token minted.
     * @param _supplyCap The maximum number of tokens that can be minted.
     * @param _startTime The start time of the sale. Tokens cannot be minted before this time.
     * @param _endTime The end time of the sale. Tokens cannot be minted after this time.
     * @dev A zero end time indicates an inactive sale.
     */
    function setGlobalSaleDetails(
        address _paymentTokenAddr,
        uint256 _cost,
        uint256 _supplyCap,
        uint64 _startTime,
        uint64 _endTime
    )
        public
        onlyRole(MINT_ADMIN_ROLE)
    {
        _paymentToken = _paymentTokenAddr;
        _globalSaleDetails = SaleDetails(_cost, _startTime, _endTime);
        totalSupplyCap = _supplyCap;
        emit GlobalSaleDetailsUpdated(_cost, _supplyCap, _startTime, _endTime);
    }

    /**
     * Set the sale details for an individual token.
     * @param _tokenId The token ID to set the sale details for.
     * @param _cost The amount of payment tokens to accept for each token minted.
     * @param _supplyCap The maximum number of tokens that can be minted.
     * @param _startTime The start time of the sale. Tokens cannot be minted before this time.
     * @param _endTime The end time of the sale. Tokens cannot be minted after this time.
     * @dev A zero end time indicates an inactive sale.
     */
    function setTokenSaleDetails(
        uint256 _tokenId,
        uint256 _cost,
        uint256 _supplyCap,
        uint64 _startTime,
        uint64 _endTime
    )
        public
        onlyRole(MINT_ADMIN_ROLE)
    {
        _tokenSaleDetails[_tokenId] = SaleDetails(_cost, _startTime, _endTime);
        tokenSupplyCap[_tokenId] = _supplyCap;
        emit TokenSaleDetailsUpdated(_tokenId, _cost, _supplyCap, _startTime, _endTime);
    }

    //
    // Withdraw
    //

    /**
     * Withdraws ETH or ERC20 tokens owned by this sale contract.
     * @param _to Address to withdraw to.
     * @param _amount Amount to withdraw.
     * @dev Withdraws ERC20 when paymentToken is set, else ETH.
     * @notice Only callable by the contract admin.
     */
    function withdraw(address _to, uint256 _amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_paymentToken == address(0)) {
            (bool success,) = _to.call{value: _amount}("");
            if (!success) {
                revert WithdrawFailed();
            }
        } else {
            (bool success) = IERC20(_paymentToken).transfer(_to, _amount);
            if (!success) {
                revert WithdrawFailed();
            }
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
    function globalSaleDetails() external view returns (SaleDetails memory) {
        return _globalSaleDetails;
    }

    /**
     * Get token sale details.
     * @param _tokenId Token ID to get sale details for.
     * @return Sale details.
     * @notice Token sale details override global sale details.
     */
    function tokenSaleDetails(uint256 _tokenId) external view returns (SaleDetails memory) {
        return _tokenSaleDetails[_tokenId];
    }

    /**
     * Get payment token.
     * @return Payment token address.
     * @notice address(0) indicates payment in ETH.
     */
    function paymentToken() external view returns (address) {
        return _paymentToken;
    }
}
