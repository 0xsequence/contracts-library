// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IGenericToken } from "./IGenericToken.sol";

import { ERC1155, ERC1155BaseToken } from "src/tokens/ERC1155/ERC1155BaseToken.sol";

contract ERC1155Mock is ERC1155BaseToken, IGenericToken {

    constructor(address owner, string memory tokenBaseURI) {
        _initialize(owner, "", tokenBaseURI, "", address(0), bytes32(0));
    }

    function mint(address to, uint256 tokenId, uint256 amount) external override {
        _mint(to, tokenId, amount, "");
    }

    function approve(address owner, address operator, uint256, uint256 amount) external override {
        _setApprovalForAll(owner, operator, amount > 0);
    }

    function balanceOf(address owner, uint256 tokenId) public view override(ERC1155, IGenericToken) returns (uint256) {
        return ERC1155.balanceOf(owner, tokenId);
    }

}
