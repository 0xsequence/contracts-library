// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {
    ERC721AQueryable, IERC721AQueryable, ERC721A, IERC721A
} from "erc721a/contracts/extensions/ERC721AQueryable.sol";
import {ERC2981Controlled} from "@0xsequence/contracts-library/tokens/common/ERC2981Controlled.sol";

error InvalidInitialization();

/**
 * A standard base implementation of ERC-721 for use in Sequence library contracts.
 */
abstract contract ERC721BaseToken is ERC721AQueryable, ERC2981Controlled {
    bytes32 internal constant METADATA_ADMIN_ROLE = keccak256("METADATA_ADMIN_ROLE");

    string private _tokenBaseURI;
    string private _tokenName;
    string private _tokenSymbol;
    string private _contractURI;

    /**
     * Deploy contract.
     */
    constructor() ERC721A("", "") {}

    /**
     * Initialize contract.
     * @param owner The owner of the contract
     * @param tokenName Name of the token
     * @param tokenSymbol Symbol of the token
     * @param tokenBaseURI Base URI of the token
     * @param tokenContractURI Contract URI of the token
     * @dev This should be called immediately after deployment.
     */
    function _initialize(
        address owner,
        string memory tokenName,
        string memory tokenSymbol,
        string memory tokenBaseURI,
        string memory tokenContractURI
    ) internal {
        _tokenName = tokenName;
        _tokenSymbol = tokenSymbol;
        _tokenBaseURI = tokenBaseURI;
        _contractURI = tokenContractURI;

        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(METADATA_ADMIN_ROLE, owner);
        _grantRole(ROYALTY_ADMIN_ROLE, owner);
    }

    //
    // Metadata
    //

    /**
     * Set name and symbol of token.
     * @param tokenName Name of token.
     * @param tokenSymbol Symbol of token.
     */
    function setNameAndSymbol(string memory tokenName, string memory tokenSymbol)
        external
        onlyRole(METADATA_ADMIN_ROLE)
    {
        _tokenName = tokenName;
        _tokenSymbol = tokenSymbol;
    }

    /**
     * Update the base URI of token's URI.
     * @param tokenBaseURI New base URI of token's URI
     */
    function setBaseMetadataURI(string memory tokenBaseURI) external onlyRole(METADATA_ADMIN_ROLE) {
        _tokenBaseURI = tokenBaseURI;
    }

    /**
     * Update the contract URI of token's URI.
     * @param tokenContractURI New contract URI of token's URI
     * @notice Refer to https://docs.opensea.io/docs/contract-level-metadata
     */
    function setContractURI(string memory tokenContractURI) external onlyRole(METADATA_ADMIN_ROLE) {
        _contractURI = tokenContractURI;
    }

    //
    // Burn
    //

    /**
     * Allows the owner of the token to burn their token.
     * @param tokenId Id of token to burn
     */
    function burn(uint256 tokenId) public virtual {
        _burn(tokenId, true);
    }

    /**
     * Allows the owner of the tokens to burn their tokens.
     * @param tokenIds Array of token ids to burn
     */
    function batchBurn(uint256[] memory tokenIds) public virtual {
        uint256 nBurn = tokenIds.length;
        for (uint256 i = 0; i < nBurn; i++) {
            _burn(tokenIds[i], true);
        }
    }

    //
    // Views
    //

    /**
     * Get the contract URI of token's URI.
     * @return Contract URI of token's URI
     * @notice Refer to https://docs.opensea.io/docs/contract-level-metadata
     */
    function contractURI() public view returns (string memory) {
        return _contractURI;
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
        override(ERC721A, IERC721A, ERC2981Controlled)
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
    function name() public view override(ERC721A, IERC721A) returns (string memory) {
        return _tokenName;
    }

    /**
     * Override the ERC721A symbol function.
     */
    function symbol() public view override(ERC721A, IERC721A) returns (string memory) {
        return _tokenSymbol;
    }
}
