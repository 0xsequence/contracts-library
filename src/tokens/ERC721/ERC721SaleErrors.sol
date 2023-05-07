// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

// A contract for errors for extensibility.
abstract contract ERC721SaleErrors {
    /**
     * Contract already initialized.
     */
    error InvalidInitialization();

    /**
     * Sale is not active.
     */
    error SaleInactive();

    /**
     * Insufficient supply.
     * @param currentSupply Current supply.
     * @param amount Amount to mint.
     * @param maxSupply Maximum supply.
     */
    error InsufficientSupply(uint256 currentSupply, uint256 amount, uint256 maxSupply);

    /**
     * Insufficient tokens for payment.
     * @param expected Expected amount of tokens.
     * @param actual Actual amount of tokens.
     */
    error InsufficientPayment(uint256 expected, uint256 actual);

    /**
     * Withdraw failed.
     */
    error WithdrawFailed();
}
