// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IERC721ItemsFunctions {

    /**
     * Mint tokens.
     * @param to Address to mint tokens to.
     * @param tokenId Token id to mint.
     */
    function mint(address to, uint256 tokenId) external;

    /**
     * Mint a sequential token.
     * @param to Address to mint token to.
     * @param amount Amount of tokens to mint.
     */
    function mintSequential(address to, uint256 amount) external;

    /**
     * Get the total supply of tokens.
     * @return totalSupply The total supply of tokens.
     */
    function totalSupply() external view returns (uint256 totalSupply);

}

interface IERC721ItemsSignals {

    /**
     * Invalid initialization error.
     */
    error InvalidInitialization();

}

interface IERC721Items is IERC721ItemsFunctions, IERC721ItemsSignals { }
