// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {
    ERC1155PackedBalance,
    ERC1155MintBurnPackedBalance
} from "@0xsequence/erc-1155/contracts/tokens/ERC1155PackedBalance/ERC1155MintBurnPackedBalance.sol";
import {ERC1155MetaPackedBalance} from
    "@0xsequence/erc-1155/contracts/tokens/ERC1155PackedBalance/ERC1155MetaPackedBalance.sol";
import {ERC1155Metadata} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155Metadata.sol";
import {ERC2981Controlled} from "../../common/ERC2981Controlled.sol";

error InvalidInitialization();

/**
 * A ready made implementation of ERC-1155.
 */
contract ERC1155PackedToken is
    ERC1155MintBurnPackedBalance,
    ERC1155MetaPackedBalance,
    ERC1155Metadata,ERC2981Controlled
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
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
    function initialize(address owner, string memory name_, string memory baseURI_) public {
        if (msg.sender != initializer || initialized) {
            revert InvalidInitialization();
        }
        initialized = true;

        name = name_;
        baseURI = baseURI_;

        _setupRole(DEFAULT_ADMIN_ROLE, owner);
        _setupRole(MINTER_ROLE, owner);
        _setupRole(ROYALTY_ADMIN_ROLE, owner);
        _setupRole(METADATA_ADMIN_ROLE, owner);
    }

    //
    // Minting
    //

    /**
     * Mint tokens.
     * @param to Address to mint tokens to.
     * @param tokenId Token ID to mint.
     * @param amount Amount of tokens to mint.
     * @param data Data to pass if receiver is contract.
     */
    function mint(address to, uint256 tokenId, uint256 amount, bytes memory data) external onlyRole(MINTER_ROLE) {
        _mint(to, tokenId, amount, data);
    }

    /**
     * Mint tokens.
     * @param to Address to mint tokens to.
     * @param tokenIds Token IDs to mint.
     * @param amounts Amounts of tokens to mint.
     * @param data Data to pass if receiver is contract.
     */
    function batchMint(address to, uint256[] memory tokenIds, uint256[] memory amounts, bytes memory data)
        external
        onlyRole(MINTER_ROLE)
    {
        _batchMint(to, tokenIds, amounts, data);
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
        override (ERC1155PackedBalance, ERC1155Metadata, ERC2981Controlled)
        returns (bool)
    {
        return ERC1155PackedBalance.supportsInterface(interfaceId) || ERC1155Metadata.supportsInterface(interfaceId)
            || ERC2981Controlled.supportsInterface(interfaceId)
            || super.supportsInterface(interfaceId);
    }
}
