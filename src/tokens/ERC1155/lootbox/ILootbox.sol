// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface ILootboxFunctions {
    struct BoxContent {
        address[] tokenAddresses;
        uint256[] tokenIds;
        uint256[] amounts;
    }
}

interface ILootboxSignals {
    /// @notice Emits when a user make a commitment
    event Commit(address user);
}

// solhint-disable-next-line no-empty-blocks
interface ILootbox is ILootboxFunctions, ILootboxSignals {}
