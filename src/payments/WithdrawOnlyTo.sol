// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IWithdrawControlled } from "../tokens/common/IWithdrawControlled.sol";

error AlreadyInitialized();

contract WithdrawOnlyTo {

    address public withdrawTo;

    constructor(
        address to
    ) {
        withdrawTo = to;
    }

    function initialize(
        address to
    ) external {
        if (withdrawTo != address(0)) {
            revert AlreadyInitialized();
        }
        withdrawTo = to;
    }

    function withdrawERC20(address from, address token, uint256 value) external {
        IWithdrawControlled(from).withdrawERC20(token, withdrawTo, value);
    }

    function withdrawETH(address from, uint256 value) external {
        IWithdrawControlled(from).withdrawETH(withdrawTo, value);
    }

}
