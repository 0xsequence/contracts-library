// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IERC1155PermissiveMinterFunctions {
    /**
     * Mint tokens.
     * @param to Address to mint tokens to.
     * @param tokenId Token ID to mint.
     * @param amount Amount of tokens to mint.
     * @param data Data to pass if receiver is contract.
     */
    function mint(address to, uint256 tokenId, uint256 amount, bytes memory data) external;
}

interface IERC1155PermissiveMinterSignals {
    /**
     * Invalid initialization error.
     */
    error InvalidInitialization();
}

interface IERC1155PermissiveMinter is IERC1155PermissiveMinterFunctions, IERC1155PermissiveMinterSignals {}
