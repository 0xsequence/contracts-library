// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IGenericToken} from "./IGenericToken.sol";
import {ERC20BaseToken} from "src/tokens/ERC20/ERC20BaseToken.sol";

contract ERC20Mock is ERC20BaseToken, IGenericToken {
    constructor(address owner) {
        initialize(owner, "", "", 18);
    }

    function mint(address to, uint256, uint256 amount) external override {
        _mint(to, amount);
    }

    function approve(address owner, address operator, uint256, uint256 amount) external override {
        _approve(owner, operator, amount);
    }

    function balanceOf(address owner, uint256) external view override returns (uint256) {
        return balanceOf(owner);
    }
}
