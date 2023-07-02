// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

interface IERC1155TokenMinterFunctions {
    /**
     * Mint tokens.
     * @param to Address to mint tokens to.
     * @param tokenId Token ID to mint.
     * @param amount Amount of tokens to mint.
     * @param data Data to pass if receiver is contract.
     */
    function mint(address to, uint256 tokenId, uint256 amount, bytes memory data) external;

    /**
     * Mint tokens.
     * @param to Address to mint tokens to.
     * @param tokenIds Token IDs to mint.
     * @param amounts Amounts of tokens to mint.
     * @param data Data to pass if receiver is contract.
     */
    function batchMint(address to, uint256[] memory tokenIds, uint256[] memory amounts, bytes memory data) external;
}

interface IERC1155TokenMinterSignals {
    /**
     * Invalid initialization error.
     */
    error InvalidInitialization();
}

interface IERC1155TokenMinter is IERC1155TokenMinterFunctions, IERC1155TokenMinterSignals {}
