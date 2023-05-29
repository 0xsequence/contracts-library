// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

/// @author Michael Standen
/// @notice Based on the DropERC721 contract by thirdweb

import "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";

import "@thirdweb-dev/contracts/eip/ERC721AVirtualApproveUpgradeable.sol";

import "@thirdweb-dev/contracts/openzeppelin-presets/metatx/ERC2771ContextUpgradeable.sol";
import "@thirdweb-dev/contracts/lib/CurrencyTransferLib.sol";

import "@thirdweb-dev/contracts/extension/Royalty.sol";
import "@thirdweb-dev/contracts/extension/PrimarySale.sol";
import "@thirdweb-dev/contracts/extension/Permissions.sol";
import "@thirdweb-dev/contracts/extension/Drop.sol";

contract ERC721Sale is
    Initializable,
    Royalty,
    PrimarySale,
    Permissions,
    Drop,
    ERC2771ContextUpgradeable,
    MulticallUpgradeable,
    ERC721AUpgradeable
{
    using StringsUpgradeable for uint256;

    /// @dev Global max total supply of NFTs.
    uint256 public maxTotalSupply;

    /// @dev Emitted when the global max supply of tokens is updated.
    event MaxTotalSupplyUpdated(uint256 maxTotalSupply);

    /// @dev Base URI for all tokens.
    string private baseURI;

    //
    // Initialization
    //
    constructor() initializer {}

    /**
     * Initialize the contract.
     * @param _defaultAdmin The default admin role for the contract.
     * @param _name The name of the collection.
     * @param _symbol The symbol of the collection.
     * @param _trustedForwarders The trusted forwarders for the contract. See ERC-2771.
     * @param _primarySaleRecipient The address to receive sale proceeds.
     * @param _royaltyRecipient The address to receive royalty payments.
     * @param _royaltyBps The royalty basis points.
     * @dev This function should be called right after the contract is deployed.
     */
    function initialize(
        address _defaultAdmin,
        string memory _name,
        string memory _symbol,
        address[] memory _trustedForwarders,
        address _primarySaleRecipient,
        address _royaltyRecipient,
        uint128 _royaltyBps
    )
        external
        initializer
    {
        __ERC2771Context_init(_trustedForwarders);
        __ERC721A_init(_name, _symbol);

        _setupRole(DEFAULT_ADMIN_ROLE, _defaultAdmin);

        _setupDefaultRoyaltyInfo(_royaltyRecipient, _royaltyBps);
        _setupPrimarySaleRecipient(_primarySaleRecipient);
    }

    //
    // Sale Logic
    //

    /**
     * Set the global max total supply of tokens.
     * @param _maxTotalSupply The new max total supply.
     * @notice This function can only be called by the contract admin.
     */
    function setMaxTotalSupply(uint256 _maxTotalSupply) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxTotalSupply = _maxTotalSupply;
        emit MaxTotalSupplyUpdated(_maxTotalSupply);
    }

    /**
     * Admin can mint tokens.
     * @param _receiver The address to receive the tokens.
     * @param _quantity The quantity of tokens to mint.
     * @notice This function can only be called by the contract admin.
     */
    function adminClaim(address _receiver, uint256 _quantity) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _withinSupply(_quantity);
        _transferTokensOnClaim(_receiver, _quantity);
    }

    //
    // Metadata
    //

    /**
     * Set the base URI for all tokens.
     * @param newBaseURI The new base URI.
     * @notice This function can only be called by the contract admin.
     */
    function setBaseURI(string memory newBaseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        baseURI = newBaseURI;
    }

    /**
     * Base URI for computing {tokenURI}.
     * @dev The resulting URI for each token will be the concatenation of the `baseURI` and the `tokenId`.
     */
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    //
    // Internal hooks
    //

    /**
     * Tests whether the given quantity of tokens can be minted.
     * @param _quantity The quantity of tokens to mint.
     * @dev Reverts if the quantity exceeds the max total supply.
     */
    function _withinSupply(uint256 _quantity) internal view {
        require(maxTotalSupply == 0 || _currentIndex + _quantity <= maxTotalSupply, "exceed max total supply");
    }

    /**
     * Hook that is called before tokens are minted.
     * @param _quantity The quantity of tokens to mint.
     */
    function _beforeClaim(address, uint256 _quantity, address, uint256, AllowlistProof calldata, bytes memory)
        internal
        view
        override
    {
        _withinSupply(_quantity);
    }

    /**
     * Collects and distributes the primary sale value of NFTs being claimed.
     * @param _primarySaleRecipient The address to receive the primary sale value.
     * @param _quantityToClaim The quantity of tokens to mint.
     * @param _currency The currency to use for the primary sale.
     * @param _pricePerToken The price per token for the primary sale.
     * @dev Reverts if the price cannot be collected.
     * @notice Sends the price directly to the `_primarySaleRecipient`.
     */
    function _collectPriceOnClaim(
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
    function _transferTokensOnClaim(address _to, uint256 _quantityBeingClaimed)
        internal
        override
        returns (uint256 startTokenId)
    {
        startTokenId = _currentIndex;
        _safeMint(_to, _quantityBeingClaimed);
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
     * Burns `tokenId`.
     * @param tokenId The token to burn.
     * @notice Only callable by an approved operator.
     * @dev Reverts if the caller is not approved for the token.
     */
    function burn(uint256 tokenId) external virtual {
        // ERC721AUpgradeable's `_burn(uint256,bool)` internally checks for token approvals.
        _burn(tokenId, true);
    }

    //
    // Context
    //

    /**
     * Returns the msg sender within the given context.
     * @return The msg sender.
     */
    function _msgSender()
        internal
        view
        virtual
        override (ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    /**
     * Returns the msg data within the given context.
     * @return The msg data.
     */
    function _msgData()
        internal
        view
        virtual
        override (ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    //
    // Views
    //

    /// @inheritdoc IERC165Upgradeable
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override (ERC721AUpgradeable, IERC165)
        returns (bool)
    {
        return super.supportsInterface(interfaceId) || type(IERC2981Upgradeable).interfaceId == interfaceId;
    }
}
