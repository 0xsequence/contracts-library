// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {
    ERC721AQueryable, IERC721AQueryable, ERC721A, IERC721A
} from "erc721a/contracts/extensions/ERC721AQueryable.sol";
import {ERC2981Controlled} from "@0xsequence/contracts-library/tokens/common/ERC2981Controlled.sol";

error InvalidInitialization();

/**
 * A standard base implementation of ERC-721 for use in Sequence library contracts.
 */
abstract contract ERC721Token is ERC721AQueryable, ERC2981Controlled {
    bytes32 public constant METADATA_ADMIN_ROLE = keccak256("METADATA_ADMIN_ROLE");

    string private _tokenBaseURI;
    string private _tokenName;
    string private _tokenSymbol;

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
     * @param owner The owner of the contract
     * @param tokenName Name of the token
     * @param tokenSymbol Symbol of the token
     * @param tokenBaseURI Base URI of the token
     * @dev This should be called immediately after deployment.
     */
    function initialize(address owner, string memory tokenName, string memory tokenSymbol, string memory tokenBaseURI) public virtual {
        if (msg.sender != _initializer || _initialized) {
            revert InvalidInitialization();
        }

        _tokenName = tokenName;
        _tokenSymbol = tokenSymbol;
        _tokenBaseURI = tokenBaseURI;

        _setupRole(DEFAULT_ADMIN_ROLE, owner);
        _setupRole(METADATA_ADMIN_ROLE, owner);
        _setupRole(ROYALTY_ADMIN_ROLE, owner);

        _initialized = true;
    }

    //
    // Metadata
    //

    /**
     * Update the base URL of token's URI.
     * @param tokenBaseURI New base URL of token's URI
     */
    function setBaseMetadataURI(string memory tokenBaseURI) external onlyRole(METADATA_ADMIN_ROLE) {
        _tokenBaseURI = tokenBaseURI;
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
        virtual
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
        return _tokenBaseURI;
    }

    /**
     * Override the ERC721A name function.
     */
    function name() public view override (ERC721A, IERC721A) returns (string memory) {
        return _tokenName;
    }

    /**
     * Override the ERC721A symbol function.
     */
    function symbol() public view override (ERC721A, IERC721A) returns (string memory) {
        return _tokenSymbol;
    }
}
