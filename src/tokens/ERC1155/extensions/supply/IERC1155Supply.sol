// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IERC1155SupplySignals {

    /**
     * Insufficient supply of tokens.
     */
    error InsufficientSupply(uint256 currentSupply, uint256 requestedAmount, uint256 maxSupply);

    /**
     * Invalid array input length.
     */
    error InvalidArrayLength();
}

interface IERC1155Supply is IERC1155SupplySignals {}
