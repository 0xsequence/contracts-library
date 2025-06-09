// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { SignalsImplicitModeControlled } from "../../../common/SignalsImplicitModeControlled.sol";
import { IERC721ItemsFunctions } from "../../presets/items/IERC721Items.sol";

/**
 * An ERC-721 contract that allows permissive minting.
 */
contract ERC721PermissiveMinter is SignalsImplicitModeControlled {

    constructor(address owner, address implicitModeValidator, bytes32 implicitModeProjectId) {
        _initializeImplicitMode(owner, implicitModeValidator, implicitModeProjectId);
    }

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
