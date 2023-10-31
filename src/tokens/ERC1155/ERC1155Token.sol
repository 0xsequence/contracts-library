// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {ERC1155, ERC1155MintBurn} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155MintBurn.sol";
import {ERC1155Meta} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155Meta.sol";
import {ERC1155Metadata} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155Metadata.sol";
import {ERC2981Controlled} from "@0xsequence/contracts-library/tokens/common/ERC2981Controlled.sol";

error InvalidInitialization();

/**
 * A standard base implementation of ERC-1155 for use in Sequence library contracts.
 */
abstract contract ERC1155Token is ERC1155MintBurn, ERC1155Meta, ERC1155Metadata, ERC2981Controlled {
    bytes32 public constant METADATA_ADMIN_ROLE = keccak256("METADATA_ADMIN_ROLE");

    /**
     * Deploy contract.
     */
    constructor() ERC1155Metadata("", "") {}

    /**
     * Initialize the contract.
     * @param owner Owner address.
     * @param tokenName Token name.
     * @param tokenBaseURI Base URI for token metadata.
     * @dev This should be called immediately after deployment.
     */
    function _initialize(address owner, string memory tokenName, string memory tokenBaseURI) internal {
        name = tokenName;
        baseURI = tokenBaseURI;

        _setupRole(DEFAULT_ADMIN_ROLE, owner);
        _setupRole(ROYALTY_ADMIN_ROLE, owner);
        _setupRole(METADATA_ADMIN_ROLE, owner);
    }

    //
    // Metadata
    //

    /**
     * Update the base URL of token's URI.
     * @param tokenBaseURI New base URL of token's URI
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
        override (ERC1155, ERC1155Metadata, ERC2981Controlled)
        returns (bool)
    {
        return ERC1155.supportsInterface(interfaceId) || ERC1155Metadata.supportsInterface(interfaceId)
            || ERC2981Controlled.supportsInterface(interfaceId) || super.supportsInterface(interfaceId);
    }
}
