// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {
    IERC20Upgradeable,
    PaymentSplitterUpgradeable
} from "lib/openzeppelin-contracts-upgradeable/contracts/finance/PaymentSplitterUpgradeable.sol";

contract PaymentSplitter is PaymentSplitterUpgradeable {

    /**
     * Initialize the PaymentSplitter contract.
     * @param payees The addresses of the payees
     * @param shares The number of shares each payee has
     * @dev This function should be called only once immediately after the contract is deployed.
     */
    function initialize(address[] memory payees, uint256[] memory shares) public initializer {
        __PaymentSplitter_init(payees, shares);
    }

}
