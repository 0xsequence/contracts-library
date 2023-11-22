// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IERC20ItemsFunctions {

    /**
     * Mint tokens.
     * @param to Address to mint tokens to.
     * @param amount Amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external;

    /**
     * Set name and symbol of token.
     * @param tokenName Name of token.
     * @param tokenSymbol Symbol of token.
     */
    function setNameAndSymbol(string memory tokenName, string memory tokenSymbol) external;
}

interface IERC20ItemsSignals {
    /**
     * Invalid initialization error.
     */
    error InvalidInitialization();
}

interface IERC20Items is IERC20ItemsFunctions, IERC20ItemsSignals {}
