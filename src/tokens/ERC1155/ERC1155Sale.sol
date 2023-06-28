// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {IERC1155Sale} from "./IERC1155Sale.sol";
import {ERC1155Supply, ERC1155Token} from "./ERC1155Supply.sol";
import {ERC1155SaleErrors} from "./ERC1155SaleErrors.sol";
import {WithdrawControlled, AccessControl, SafeERC20, IERC20} from "../common/WithdrawControlled.sol";

contract ERC1155Sale is
    IERC1155Sale,
    ERC1155SaleErrors,
    ERC1155Supply,
    WithdrawControlled
{
    bytes32 public constant MINT_ADMIN_ROLE = keccak256("MINT_ADMIN_ROLE");

    bytes4 private constant _ERC20_TRANSFERFROM_SELECTOR =
        bytes4(keccak256(bytes("transferFrom(address,address,uint256)")));

    bool private _initialized;

    // ERC20 token address for payment. address(0) indicated payment in ETH.
    address private _paymentToken;

    SaleDetails private _globalSaleDetails;
    mapping(uint256 => SaleDetails) private _tokenSaleDetails;

    /**
     * Initialize the contract.
     * @param owner Owner address.
     * @param tokenName Token name.
     * @param tokenBaseURI Base URI for token metadata.
     * @dev This should be called immediately after deployment.
     */
    function initialize(address owner, string memory tokenName, string memory tokenBaseURI) public virtual override {
        if (_initialized) {
            revert InvalidInitialization();
        }
        ERC1155Token.initialize(owner, tokenName, tokenBaseURI);

        name = tokenName;
        baseURI = tokenBaseURI;
        _setupRole(DEFAULT_ADMIN_ROLE, owner);
        _setupRole(MINT_ADMIN_ROLE, owner);
        _setupRole(WITHDRAW_ROLE, owner);

        _initialized = true;
    }

    /**
     * Checks if the current block.timestamp is out of the give timestamp range.
     * @param _startTime Earliest acceptable timestamp (inclusive).
     * @param _endTime Latest acceptable timestamp (exclusive).
     * @dev A zero endTime value is always considered out of bounds.
     */
    function blockTimeOutOfBounds(uint256 _startTime, uint256 _endTime) private view returns (bool) {
        // 0 end time indicates inactive sale.
        return _endTime == 0 || block.timestamp < _startTime || block.timestamp >= _endTime; // solhint-disable-line not-rely-on-time
    }

    /**
     * Checks the sale is active and takes payment.
     * @param _tokenIds Token IDs to mint.
     * @param _amounts Amounts of tokens to mint.
     */
    function _payForActiveMint(uint256[] memory _tokenIds, uint256[] memory _amounts) private {
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
            SafeERC20.safeTransferFrom(IERC20(_paymentToken), msg.sender, address(this), totalCost);
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
     * @notice Sale must be active for all tokens.
     * @dev tokenIds must be sorted ascending without duplicates.
     */
    function mint(address to, uint256[] memory tokenIds, uint256[] memory amounts, bytes memory data)
        public
        payable
    {
        _payForActiveMint(tokenIds, amounts);
        _batchMint(to, tokenIds, amounts, data);
    }

    /**
     * Mint tokens as admin.
     * @param to Address to mint tokens to.
     * @param tokenIds Token IDs to mint.
     * @param amounts Amounts of tokens to mint.
     * @param data Data to pass if receiver is contract.
     * @notice Only callable by mint admin.
     */
    function mintAdmin(address to, uint256[] memory tokenIds, uint256[] memory amounts, bytes memory data)
        public
        onlyRole(MINT_ADMIN_ROLE)
    {
        _batchMint(to, tokenIds, amounts, data);
    }

    /**
     * Set the global sale details.
     * @param cost The amount of payment tokens to accept for each token minted.
     * @param supplyCap The maximum number of tokens that can be minted.
     * @param paymentTokenAddr The ERC20 token address to accept payment in. address(0) indicates ETH.
     * @param startTime The start time of the sale. Tokens cannot be minted before this time.
     * @param endTime The end time of the sale. Tokens cannot be minted after this time.
     * @dev A zero end time indicates an inactive sale.
     */
    function setGlobalSaleDetails(
        uint256 cost,
        uint256 supplyCap,
        address paymentTokenAddr,
        uint64 startTime,
        uint64 endTime
    )
        public
        onlyRole(MINT_ADMIN_ROLE)
    {
        _paymentToken = paymentTokenAddr;
        _globalSaleDetails = SaleDetails(cost, startTime, endTime);
        totalSupplyCap = supplyCap;
        emit GlobalSaleDetailsUpdated(cost, supplyCap, startTime, endTime);
    }

    /**
     * Set the sale details for an individual token.
     * @param tokenId The token ID to set the sale details for.
     * @param cost The amount of payment tokens to accept for each token minted.
     * @param supplyCap The maximum number of tokens that can be minted.
     * @param startTime The start time of the sale. Tokens cannot be minted before this time.
     * @param endTime The end time of the sale. Tokens cannot be minted after this time.
     * @dev A zero end time indicates an inactive sale.
     * @notice The payment token is set globally.
     */
    function setTokenSaleDetails(
        uint256 tokenId,
        uint256 cost,
        uint256 supplyCap,
        uint64 startTime,
        uint64 endTime
    )
        public
        onlyRole(MINT_ADMIN_ROLE)
    {
        _tokenSaleDetails[tokenId] = SaleDetails(cost, startTime, endTime);
        tokenSupplyCap[tokenId] = supplyCap;
        emit TokenSaleDetailsUpdated(tokenId, cost, supplyCap, startTime, endTime);
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
     * @param tokenId Token ID to get sale details for.
     * @return Sale details.
     * @notice Token sale details override global sale details.
     */
    function tokenSaleDetails(uint256 tokenId) external view returns (SaleDetails memory) {
        return _tokenSaleDetails[tokenId];
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
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override (ERC1155Token, AccessControl)
        returns (bool)
    {
        return interfaceId == type(IERC1155Sale).interfaceId || super.supportsInterface(interfaceId);
    }
}
