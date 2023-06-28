// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

// A contract for errors for extensibility.
abstract contract ERC1155SupplyErrors {

    /**
     * Insufficient supply of tokens.
     */
    error InsufficientSupply(uint256 currentSupply, uint256 requestedAmount, uint256 maxSupply);

    /**
     * Invalid array input length.
     */
    error InvalidArrayLength();
}
