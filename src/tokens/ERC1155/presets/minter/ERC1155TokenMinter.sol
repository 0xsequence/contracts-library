// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {ERC1155MintBurn, ERC1155} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155MintBurn.sol";
import {ERC1155TokenMinterErrors} from "@0xsequence/contracts-library/tokens/ERC1155//presets/minter/ERC1155TokenMinterErrors.sol";
import {ERC1155Token} from "@0xsequence/contracts-library/tokens/ERC1155/ERC1155Token.sol";
import {ERC2981Controlled} from "@0xsequence/contracts-library/tokens/common/ERC2981Controlled.sol";

/**
 * A ready made implementation of ERC-1155 capable of minting when role provided.
 */
contract ERC1155TokenMinter is ERC1155MintBurn, ERC1155Token, ERC1155TokenMinterErrors {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address private immutable initializer;
    bool private initialized;

    constructor() {
        initializer = msg.sender;
    }

    /**
     * Initialize the contract.
     * @param owner Owner address.
     * @param tokenName Token name.
     * @param tokenBaseURI Base URI for token metadata.
     * @dev This should be called immediately after deployment.
     */
    function initialize(address owner, string memory tokenName, string memory tokenBaseURI) public virtual override {
        if (msg.sender != initializer || initialized) {
            revert InvalidInitialization();
        }

        ERC1155Token.initialize(owner, tokenName, tokenBaseURI);

        _setupRole(MINTER_ROLE, owner);

        initialized = true;
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
    // Views
    //

    /**
     * Check interface support.
     * @param interfaceId Interface id
     * @return True if supported
     */
    function supportsInterface(bytes4 interfaceId) public view override (ERC1155Token, ERC1155) returns (bool) {
        return ERC1155Token.supportsInterface(interfaceId);
    }
}
