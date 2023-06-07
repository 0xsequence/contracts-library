// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {
    ERC721AQueryable, IERC721AQueryable, ERC721A, IERC721A
} from "erc721a/contracts/extensions/ERC721AQueryable.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

error InvalidInitialization();

/**
 * A ready made implementation of ERC-721.
 */
contract ERC721Token is ERC721AQueryable, ERC2981, AccessControl {
    bytes32 public constant METADATA_ADMIN_ROLE = keccak256("METADATA_ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant ROYALTY_ADMIN_ROLE = keccak256("ROYALTY_ADMIN_ROLE");

    string private baseURI; // Missing _ due to _baseURI() function in ERC721A
    string private _name;
    string private _symbol;

    address private immutable _initializer;
    bool private _initialized;

    /**
     * Deploy contract.
     */
    constructor() ERC721A("", "") {
        _initializer = msg.sender;
    }

    /**
     * Initialize contract.
     * @param owner_ The owner of the contract
     * @param name_ Name of the token
     * @param symbol_ Symbol of the token
     * @param baseURI_ Base URI of the token
     * @dev This should be called immediately after deployment.
     */
    function initialize(address owner_, string memory name_, string memory symbol_, string memory baseURI_) external {
        if (msg.sender != _initializer || _initialized) {
            revert InvalidInitialization();
        }
        _initialized = true;

        _name = name_;
        _symbol = symbol_;
        baseURI = baseURI_;

        _setupRole(DEFAULT_ADMIN_ROLE, owner_);
        _setupRole(METADATA_ADMIN_ROLE, owner_);
        _setupRole(MINTER_ROLE, owner_);
        _setupRole(ROYALTY_ADMIN_ROLE, owner_);
    }

    //
    // Minting
    //

    /**
     * Mint tokens.
     * @param _to Address to mint tokens to.
     * @param _amount Amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount) external onlyRole(MINTER_ROLE) {
        _mint(_to, _amount);
    }

    //
    // Royalty
    //

    /**
     * Sets the royalty information that all ids in this contract will default to.
     * @param _receiver Address of who should be sent the royalty payment
     * @param _feeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     */
    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) external onlyRole(ROYALTY_ADMIN_ROLE) {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    /**
     * Sets the royalty information that a given token id in this contract will use.
     * @param _tokenId The token id to set the royalty information for
     * @param _receiver Address of who should be sent the royalty payment
     * @param _feeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @notice This overrides the default royalty information for this token id
     */
    function setTokenRoyalty(uint256 _tokenId, address _receiver, uint96 _feeNumerator)
        external
        onlyRole(ROYALTY_ADMIN_ROLE)
    {
        _setTokenRoyalty(_tokenId, _receiver, _feeNumerator);
    }

    //
    // Metadata
    //

    /**
     * Update the base URL of token's URI.
     * @param _baseMetadataURI New base URL of token's URI
     */
    function setBaseMetadataURI(string memory _baseMetadataURI) external onlyRole(METADATA_ADMIN_ROLE) {
        baseURI = _baseMetadataURI;
    }

    //
    // Views
    //

    /**
     * Check interface support.
     * @param _interfaceId Interface id
     * @return True if supported
     */
    function supportsInterface(bytes4 _interfaceId)
        public
        view
        override (ERC721A, IERC721A, ERC2981, AccessControl)
        returns (bool)
    {
        return _interfaceId == type(IERC721A).interfaceId || _interfaceId == type(IERC721AQueryable).interfaceId
            || ERC721A.supportsInterface(_interfaceId) || ERC2981.supportsInterface(_interfaceId)
            || AccessControl.supportsInterface(_interfaceId) || super.supportsInterface(_interfaceId);
    }

    //
    // ERC721A Overrides
    //

    /**
     * Override the ERC721A baseURI function.
     */
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    /**
     * Override the ERC721A name function.
     */
    function name() public view override (ERC721A, IERC721A) returns (string memory) {
        return _name;
    }

    /**
     * Override the ERC721A symbol function.
     */
    function symbol() public view override (ERC721A, IERC721A) returns (string memory) {
        return _symbol;
    }
}
