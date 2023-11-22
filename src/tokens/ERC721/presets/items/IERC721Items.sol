// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IERC721ItemsFunctions {
    /**
     * Mint tokens.
     * @param to Address to mint tokens to.
     * @param amount Amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external;
}

interface IERC721ItemsSignals {
    /**
     * Invalid initialization error.
     */
    error InvalidInitialization();
}

interface IERC721Items is IERC721ItemsFunctions, IERC721ItemsSignals {}
