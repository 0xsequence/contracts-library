// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

interface IERC1155TokenMinterSignals {

    /**
     * Invalid initialization error.
     */
    error InvalidInitialization();
}

interface IERC1155TokenMinter is IERC1155TokenMinterSignals {}
