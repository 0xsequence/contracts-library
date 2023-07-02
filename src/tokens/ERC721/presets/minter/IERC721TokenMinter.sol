// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

interface IERC721TokenMinterSignals {

    /**
     * Invalid initialization error.
     */
    error InvalidInitialization();
}

interface IERC721TokenMinter is IERC721TokenMinterSignals {}
