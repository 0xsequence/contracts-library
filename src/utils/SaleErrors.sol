// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

// A contract for errors for extensibility.
contract SaleErrors {
    /**
     * Sale is not active globally.
     */
    error GlobalSaleInactive();

    /**
     * Sale is not active.
     * @param tokenId Invalid Token ID.
     */
    error SaleInactive(uint256 tokenId);

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
