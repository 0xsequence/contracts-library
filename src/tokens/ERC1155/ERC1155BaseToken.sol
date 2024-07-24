// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {
    ERC1155Supply, ERC1155
} from "@0xsequence/contracts-library/tokens/ERC1155/extensions/supply/ERC1155Supply.sol";
import {ERC1155Metadata} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155Metadata.sol";
import {ERC2981Controlled} from "@0xsequence/contracts-library/tokens/common/ERC2981Controlled.sol";

error InvalidInitialization();

/**
 * A standard base implementation of ERC-1155 for use in Sequence library contracts.
 */
abstract contract ERC1155BaseToken is ERC1155Supply, ERC1155Metadata, ERC2981Controlled {
    bytes32 internal constant METADATA_ADMIN_ROLE = keccak256("METADATA_ADMIN_ROLE");

    string private _contractURI;

    /**
     * Deploy contract.
     */
    constructor() ERC1155Metadata("", "") {}

    /**
     * Initialize the contract.
     * @param owner Owner address.
     * @param tokenName Token name.
     * @param tokenBaseURI Base URI for token metadata.
     * @param tokenContractURI Contract URI for token metadata.
     * @dev This should be called immediately after deployment.
     */
    function _initialize(
        address owner,
        string memory tokenName,
        string memory tokenBaseURI,
        string memory tokenContractURI
    ) internal {
        name = tokenName;
        baseURI = tokenBaseURI;
        _contractURI = tokenContractURI;

        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(ROYALTY_ADMIN_ROLE, owner);
        _grantRole(METADATA_ADMIN_ROLE, owner);
    }

    //
    // Metadata
    //

    /**
     * Update the base URI of token's URI.
     * @param tokenBaseURI New base URI of token's URI
     */
    function setBaseMetadataURI(string memory tokenBaseURI) external onlyRole(METADATA_ADMIN_ROLE) {
        _setBaseMetadataURI(tokenBaseURI);
    }

    /**
     * Update the name of the contract.
     * @param tokenName New contract name
     */
    function setContractName(string memory tokenName) external onlyRole(METADATA_ADMIN_ROLE) {
        _setContractName(tokenName);
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
     * Allows the owner of the token to burn their tokens.
     * @param tokenId Id of token to burn
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 tokenId, uint256 amount) public virtual {
        _burn(msg.sender, tokenId, amount);
    }

    /**
     * Burn tokens of given token id for each (tokenIds[i], amounts[i]) pair.
     * @param tokenIds Array of token ids to burn
     * @param amounts Array of the amount to be burned
     */
    function batchBurn(uint256[] memory tokenIds, uint256[] memory amounts) public virtual {
        _batchBurn(msg.sender, tokenIds, amounts);
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
        override(ERC1155Supply, ERC1155Metadata, ERC2981Controlled)
        returns (bool)
    {
        return ERC1155Supply.supportsInterface(interfaceId) || ERC1155Metadata.supportsInterface(interfaceId)
            || ERC2981Controlled.supportsInterface(interfaceId) || super.supportsInterface(interfaceId);
    }
}
