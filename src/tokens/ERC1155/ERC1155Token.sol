// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {ERC1155, ERC1155MintBurn} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155MintBurn.sol";
import {ERC1155Meta} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155Meta.sol";
import {ERC1155Metadata} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155Metadata.sol";
import {ERC2981Controlled} from "../common/ERC2981Controlled.sol";

error InvalidInitialization();

/**
 * A ready made implementation of ERC-1155.
 */
abstract contract ERC1155Token is ERC1155MintBurn, ERC1155Meta, ERC1155Metadata, ERC2981Controlled {
    bytes32 public constant METADATA_ADMIN_ROLE = keccak256("METADATA_ADMIN_ROLE");

    address private immutable initializer;
    bool private initialized;

    /**
     * Initialize contract.
     */
    constructor() ERC1155Metadata("", "") {
        initializer = msg.sender;
    }

    /**
     * Initialize the contract.
     * @param owner Owner address.
     * @param name_ Token name.
     * @param baseURI_ Base URI for token metadata.
     * @dev This should be called immediately after deployment.
     
     */
    function _initialize(address owner, string memory name_, string memory baseURI_) internal virtual {
        if (msg.sender != initializer || initialized) {
            revert InvalidInitialization();
        }

        name = name_;
        baseURI = baseURI_;

        _setupRole(DEFAULT_ADMIN_ROLE, owner);
        _setupRole(ROYALTY_ADMIN_ROLE, owner);
        _setupRole(METADATA_ADMIN_ROLE, owner);

        initialized = true;
    }

    //
    // Metadata
    //

    /**
     * Update the base URL of token's URI.
     * @param baseURI_ New base URL of token's URI
     */
    function setBaseMetadataURI(string memory baseURI_) external onlyRole(METADATA_ADMIN_ROLE) {
        _setBaseMetadataURI(baseURI_);
    }

    /**
     * Update the name of the contract.
     * @param name_ New contract name
     */
    function setContractName(string memory name_) external onlyRole(METADATA_ADMIN_ROLE) {
        _setContractName(name_);
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
            || ERC2981Controlled.supportsInterface(interfaceId)
            || super.supportsInterface(interfaceId);
    }
}
