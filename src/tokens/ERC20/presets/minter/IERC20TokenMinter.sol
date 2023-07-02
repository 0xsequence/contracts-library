// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

interface IERC20TokenMinterSignals {

    /**
     * Invalid initialization error.
     */
    error InvalidInitialization();
}

interface IERC20TokenMinter is IERC20TokenMinterSignals {}
