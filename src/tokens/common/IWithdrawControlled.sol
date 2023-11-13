// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IWithdrawControlledFunctions {

    /**
     * Withdraws ERC20 tokens owned by this contract.
     * @param token The ERC20 token address.
     * @param to Address to withdraw to.
     * @param value Amount to withdraw.
     */
    function withdrawERC20(address token, address to, uint256 value) external;

    /**
     * Withdraws ETH owned by this sale contract.
     * @param to Address to withdraw to.
     * @param value Amount to withdraw.
     */
    function withdrawETH(address to, uint256 value) external;
}

interface IWithdrawControlledSignals {

    /**
     * Withdraw failed error.
     */
    error WithdrawFailed();
}

interface IWithdrawControlled is IWithdrawControlledFunctions, IWithdrawControlledSignals {}
