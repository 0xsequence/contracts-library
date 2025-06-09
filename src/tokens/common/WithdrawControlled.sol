// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IWithdrawControlled } from "./IWithdrawControlled.sol";

import { AccessControlEnumerable, ERC165 } from "openzeppelin-contracts/contracts/access/AccessControlEnumerable.sol";
import { IERC20, SafeERC20 } from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * An abstract contract that allows ETH and ERC20 tokens stored in the contract to be withdrawn.
 */
abstract contract WithdrawControlled is AccessControlEnumerable, IWithdrawControlled {

    bytes32 internal constant WITHDRAW_ROLE = keccak256("WITHDRAW_ROLE");

    //
    // Withdraw
    //

    /**
     * Withdraws ERC20 tokens owned by this contract.
     * @param token The ERC20 token address.
     * @param to Address to withdraw to.
     * @param value Amount to withdraw.
     * @notice Only callable by an address with the withdraw role.
     */
    function withdrawERC20(address token, address to, uint256 value) public onlyRole(WITHDRAW_ROLE) {
        SafeERC20.safeTransfer(IERC20(token), to, value);
    }

    /**
     * Withdraws ETH owned by this sale contract.
     * @param to Address to withdraw to.
     * @param value Amount to withdraw.
     * @notice Only callable by an address with the withdraw role.
     */
    function withdrawETH(address to, uint256 value) public onlyRole(WITHDRAW_ROLE) {
        (bool success,) = to.call{ value: value }("");
        if (!success) {
            revert WithdrawFailed();
        }
    }

    /// @inheritdoc ERC165
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(AccessControlEnumerable) returns (bool) {
        return interfaceId == type(IWithdrawControlled).interfaceId
            || AccessControlEnumerable.supportsInterface(interfaceId);
    }

}
