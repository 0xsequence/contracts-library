// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

/// @author Michael Standen
/// @notice Based on the DropERC1155 contract by thirdweb

import {
    ERC1155MintBurnUpgradeable,
    ERC1155Upgradeable
} from "@0xsequence/erc-1155/contracts/tokens/ERC1155Upgradeable/ERC1155MintBurnUpgradeable.sol";
import {ERC1155MetaUpgradeable} from
    "@0xsequence/erc-1155/contracts/tokens/ERC1155Upgradeable/ERC1155MetaUpgradeable.sol";
import {ERC1155MetadataUpgradeable} from
    "@0xsequence/erc-1155/contracts/tokens/ERC1155Upgradeable/ERC1155MetadataUpgradeable.sol";

import "@0xsequence/erc-1155/contracts/utils/StorageSlot.sol";

import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";

import "@thirdweb-dev/contracts/lib/CurrencyTransferLib.sol";

import "@thirdweb-dev/contracts/extension/Royalty.sol";
import "@thirdweb-dev/contracts/extension/PrimarySale.sol";
import "@thirdweb-dev/contracts/extension/Permissions.sol";
import "@thirdweb-dev/contracts/extension/Drop1155.sol";

contract ERC1155Sale is
    Royalty,
    PrimarySale,
    Permissions,
    Drop1155,
    ERC1155MintBurnUpgradeable,
    ERC1155MetadataUpgradeable,
    ERC1155MetaUpgradeable
{
    using StringsUpgradeable for uint256;

    // Token total supply
    bytes32 private constant _TOTALSUPPLY_SLOT_KEY = keccak256("0xsequence.ERC1155Sale.totalSupply");

    // Token's maximum possible total circulating supply
    bytes32 private constant _MAXTOTALSUPPLY_SLOT_KEY = keccak256("0xsequence.ERC1155Sale.maxTotalSupply");

    /// @dev Emitted when the global max supply of a token is updated.
    event MaxTotalSupplyUpdated(uint256 tokenId, uint256 maxTotalSupply);

    //
    // Initialization
    //
    constructor() initializer {}

    /**
     * Initialize the contract.
     * @param _defaultAdmin The default admin role for the contract.
     * @param _name The name of the collection.
     * @param _baseURI The base URI of the collection.
     * @param _primarySaleRecipient The address to receive sale proceeds.
     * @param _royaltyRecipient The address to receive royalty payments.
     * @param _royaltyBps The royalty basis points.
     * @dev This function should be called right after the contract is deployed.
     */
    function initialize(
        address _defaultAdmin,
        string memory _name,
        string memory _baseURI,
        address _primarySaleRecipient,
        address _royaltyRecipient,
        uint128 _royaltyBps
    )
        external
        initializer
    {
        _ERC1155MetadataUpgradeable_init(_name, _baseURI);

        _setupRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);

        _setupDefaultRoyaltyInfo(_royaltyRecipient, _royaltyBps);
        _setupPrimarySaleRecipient(_primarySaleRecipient);
    }

    //
    // Sale Logic
    //

    /**
     * Set the max total supply of tokens.
     * @param _tokenId The id of the token.
     * @param _maxTotalSupply The new max total supply.
     * @notice This function can only be called by the contract admin.
     */
    function setMaxTotalSupply(uint256 _tokenId, uint256 _maxTotalSupply) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setMaxTotalSupply(_tokenId, _maxTotalSupply);
        emit MaxTotalSupplyUpdated(_tokenId, _maxTotalSupply);
    }

    /**
     * Admin can mint tokens.
     * @param _receiver The address to receive the tokens.
     * @param _tokenId The id of the tokens to mint.
     * @param _quantity The quantity of tokens to mint.
     * @notice This function can only be called by the contract admin.
     */
    function adminClaim(address _receiver, uint256 _tokenId, uint256 _quantity) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _withinSupply(_tokenId, _quantity);
        transferTokensOnClaim(_receiver, _tokenId, _quantity);
    }

    //
    // Internal hooks
    //

    /**
     * Tests whether the given quantity of tokens can be minted.
     * @param _tokenId The id of the token.
     * @param _quantity The quantity of tokens to mint.
     * @dev Reverts if the quantity exceeds the max total supply.
     */
    function _withinSupply(uint256 _tokenId, uint256 _quantity) internal view {
        uint256 max = _getMaxTotalSupply(_tokenId);
        require(max == 0 || _getTotalSupply(_tokenId) + _quantity <= max, "exceed max total supply");
    }

    /// @dev Runs before every `claim` function call.
    function _beforeClaim(
        uint256 _tokenId,
        address,
        uint256 _quantity,
        address,
        uint256,
        AllowlistProof calldata,
        bytes memory
    )
        internal
        view
        override
    {
        _withinSupply(_tokenId, _quantity);
    }

    /**
     * Collects and distributes the primary sale value of SFTs being claimed.
     * @param _primarySaleRecipient The address to receive the primary sale value.
     * @param _quantityToClaim The quantity of tokens to mint.
     * @param _currency The currency to use for the primary sale.
     * @param _pricePerToken The price per token for the primary sale.
     * @dev Reverts if the price cannot be collected.
     * @notice Sends the price directly to the `_primarySaleRecipient`.
     */
    function collectPriceOnClaim(
        uint256,
        address _primarySaleRecipient,
        uint256 _quantityToClaim,
        address _currency,
        uint256 _pricePerToken
    )
        internal
        override
    {
        if (_pricePerToken == 0) {
            return;
        }

        uint256 totalPrice = _quantityToClaim * _pricePerToken;
        if (_currency == CurrencyTransferLib.NATIVE_TOKEN && msg.value != totalPrice) {
            revert("!Price");
        }

        address saleRecipient = _primarySaleRecipient == address(0) ? primarySaleRecipient() : _primarySaleRecipient;
        CurrencyTransferLib.transferCurrency(_currency, _msgSender(), saleRecipient, totalPrice);
    }

    /**
     * Transfers tokens to the given address.
     * @param _to The address to receive the tokens.
     * @param _quantityBeingClaimed The quantity of tokens to mint.
     */
    function transferTokensOnClaim(address _to, uint256 _tokenId, uint256 _quantityBeingClaimed) internal override {
        _mint(_to, _tokenId, _quantityBeingClaimed, "");
    }

    //
    // Internal overrides
    //

    /**
     * Checks whether primary sale recipient can be set in the given execution context.
     */
    function _canSetPrimarySaleRecipient() internal view override returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * Checks whether royalty info can be set in the given execution context.
     */
    function _canSetRoyaltyInfo() internal view override returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * Checks whether platform fee info can be set in the given execution context.
     */
    function _canSetClaimConditions() internal view override returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    //
    // Burn
    //

    /**
     * Burns tokens.
     * @param account The owner of the tokens.
     * @param ids The token ids to burn.
     * @param values The quantities of tokens to burn.
     * @notice Only callable by an approved operator.
     * @dev Reverts if the caller is not approved for the token.
     */
    function batchBurn(address account, uint256[] memory ids, uint256[] memory values) external virtual {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not owner nor approved."
        );

        _batchBurn(account, ids, values);
    }

    //
    // Supply overrides
    //

    /**
     * Update the balance of `_owner` by adding `_amount` tokens to `_tokenId`.
     * @dev Also updates the total supply of the `_tokenId` token by `_amount`.
     */
    function _updateBalance(address _owner, uint256 _tokenId, uint256 _diff, ERC1155Upgradeable.Operations _operation)
        internal
        virtual
        override
    {
        super._updateBalance(_owner, _tokenId, _diff, _operation);
        _updateTotalSupply(_tokenId, _diff, _operation);
    }

    //
    // Storage
    //
    function _getTotalSupply(uint256 _tokenId) internal view virtual returns (uint256) {
        return StorageSlot.getUint256Slot(keccak256(abi.encodePacked(_TOTALSUPPLY_SLOT_KEY, _tokenId))).value;
    }

    function _updateTotalSupply(uint256 _tokenId, uint256 _diff, ERC1155Upgradeable.Operations _operation)
        internal
        virtual
    {
        StorageSlot.Uint256Slot storage slot =
            StorageSlot.getUint256Slot(keccak256(abi.encodePacked(_TOTALSUPPLY_SLOT_KEY, _tokenId)));
        if (_operation == Operations.Add) {
            slot.value += _diff;
        } else if (_operation == Operations.Sub) {
            slot.value -= _diff;
        } else {
            revert("ERC1155Sale#_updateTotalSupply: INVALID_OPERATION");
        }
    }

    function _getMaxTotalSupply(uint256 _tokenId) internal view virtual returns (uint256) {
        return StorageSlot.getUint256Slot(keccak256(abi.encodePacked(_MAXTOTALSUPPLY_SLOT_KEY, _tokenId))).value;
    }

    function _setMaxTotalSupply(uint256 _tokenId, uint256 _value) internal virtual {
        StorageSlot.getUint256Slot(keccak256(abi.encodePacked(_MAXTOTALSUPPLY_SLOT_KEY, _tokenId))).value = _value;
    }

    //
    // Views
    //

    /**
     * Get the total supply of the given token.
     * @param _tokenId The token id to query.
     * @return The total supply of the token.
     */
    function totalSupply(uint256 _tokenId) external view returns (uint256) {
        return _getTotalSupply(_tokenId);
    }

    /**
     * Get the maximum total supply of the given token.
     * @param _tokenId The token id to query.
     * @return The maximum total supply of the token.
     */
    function maxTotalSupply(uint256 _tokenId) external view returns (uint256) {
        return _getMaxTotalSupply(_tokenId);
    }

    /// @dev See ERC 165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override (ERC1155MetadataUpgradeable, ERC1155Upgradeable, IERC165)
        returns (bool)
    {
        return super.supportsInterface(interfaceId) || type(IERC2981Upgradeable).interfaceId == interfaceId;
    }
}
