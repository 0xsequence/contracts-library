// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC721ItemsFunctions} from "@0xsequence/contracts-library/tokens/ERC721/presets/items/IERC721Items.sol";

/**
 * An ERC-721 contract that allows permissive minting.
 */
contract ERC721PermissiveMinter {
    /**
     * Mint tokens.
     * @param items The items contract.
     * @param to Address to mint tokens to.
     * @param amount Amount of tokens to mint.
     */
    function mint(address items, address to, uint256 amount) public {
        IERC721ItemsFunctions(items).mint(to, amount);
    }
}
