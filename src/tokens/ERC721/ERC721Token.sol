// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {
    ERC721AQueryable, IERC721AQueryable, ERC721A, IERC721A
} from "erc721a/contracts/extensions/ERC721AQueryable.sol";
import {ERC2981Controlled} from "../common/ERC2981Controlled.sol";

error InvalidInitialization();

/**
 * A ready made implementation of ERC-721.
 */
contract ERC721Token is ERC721AQueryable, ERC2981Controlled {
    bytes32 public constant METADATA_ADMIN_ROLE = keccak256("METADATA_ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    string private baseURI;
    string private tokenName;
    string private tokenSymbol;

    address private immutable initializer;
    bool private initialized;

    /**
     * Deploy contract.
     */
    constructor() ERC721A("", "") {
        initializer = msg.sender;
    }

    /**
     * Initialize contract.
     * @param owner The owner of the contract
     * @param tokenName_ Name of the token
     * @param tokenSymbol_ Symbol of the token
     * @param baseURI_ Base URI of the token
     * @dev This should be called immediately after deployment.
     */
    function initialize(address owner, string memory tokenName_, string memory tokenSymbol_, string memory baseURI_) external {
        if (msg.sender != initializer || initialized) {
            revert InvalidInitialization();
        }
        initialized = true;

        tokenName = tokenName_;
        tokenSymbol = tokenSymbol_;
        baseURI = baseURI_;

        _setupRole(DEFAULT_ADMIN_ROLE, owner);
        _setupRole(METADATA_ADMIN_ROLE, owner);
        _setupRole(MINTER_ROLE, owner);
        _setupRole(ROYALTY_ADMIN_ROLE, owner);
    }

    //
    // Minting
    //

    /**
     * Mint tokens.
     * @param to Address to mint tokens to.
     * @param amount Amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    //
    // Metadata
    //

    /**
     * Update the base URL of token's URI.
     * @param baseURI_ New base URL of token's URI
     */
    function setBaseMetadataURI(string memory baseURI_) external onlyRole(METADATA_ADMIN_ROLE) {
        baseURI = baseURI_;
    }

    //
    // Views
    //

    /**
     * Check interface support.
     * @param interfaceId Interface id
     * @return True if supported
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override (ERC721A, IERC721A, ERC2981Controlled)
        returns (bool)
    {
        return interfaceId == type(IERC721A).interfaceId || interfaceId == type(IERC721AQueryable).interfaceId
            || ERC721A.supportsInterface(interfaceId) || ERC2981Controlled.supportsInterface(interfaceId)
            || super.supportsInterface(interfaceId);
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
        return tokenName;
    }

    /**
     * Override the ERC721A symbol function.
     */
    function symbol() public view override (ERC721A, IERC721A) returns (string memory) {
        return tokenSymbol;
    }
}
