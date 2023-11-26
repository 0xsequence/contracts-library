// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IERC1155SupplyFunctions {

    /**
     * Returns the total supply of ERC1155 tokens.
     */
    function totalSupply() external returns (uint256);

    /**
     * Returns the total supply of a given ERC1155 token.
     * @param tokenId The ERC1155 token id.
     */
    function tokenSupply(uint256 tokenId) external returns (uint256);
}

interface IERC1155SupplySignals {

    /**
     * Invalid array input length.
     */
    error InvalidArrayLength();
}

interface IERC1155Supply is IERC1155SupplySignals {}
