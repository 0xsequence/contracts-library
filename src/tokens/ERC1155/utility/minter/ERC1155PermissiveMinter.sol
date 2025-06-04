// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { SignalsImplicitModeControlled } from "../../../common/SignalsImplicitModeControlled.sol";
import { IERC1155ItemsFunctions } from "../../presets/items/IERC1155Items.sol";

/**
 * An ERC-1155 contract that allows permissive minting.
 */
contract ERC1155PermissiveMinter is SignalsImplicitModeControlled {

    constructor(address owner, address implicitModeValidator, bytes32 implicitModeProjectId) {
        _initializeImplicitMode(owner, implicitModeValidator, implicitModeProjectId);
    }

    /**
     * Mint tokens.
     * @param items The items contract.
     * @param to Address to mint tokens to.
     * @param tokenId Token ID to mint.
     * @param amount Amount of tokens to mint.
     * @param data Data to pass if receiver is contract.
     */
    function mint(address items, address to, uint256 tokenId, uint256 amount, bytes memory data) external {
        IERC1155ItemsFunctions(items).mint(to, tokenId, amount, data);
    }

    /**
     * Batch mint tokens.
     * @param items The items contract.
     * @param to Address to mint tokens to.
     * @param tokenIds Token IDs to mint.
     * @param amounts Amounts of tokens to mint.
     * @param data Data to pass if receiver is contract.
     */
    function batchMint(
        address items,
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts,
        bytes memory data
    ) external {
        IERC1155ItemsFunctions(items).batchMint(to, tokenIds, amounts, data);
    }

}
