// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IERC1155SoulboundFunctions {

    /**
     * Sets the transfer lock.
     * @param locked Whether or not transfers are locked.
     */
    function setTransferLocked(
        bool locked
    ) external;

    /**
     * Gets the transfer lock.
     * @return Whether or not transfers are locked.
     */
    function getTransferLocked() external view returns (bool);

}

interface IERC1155SoulboundSignals {

    /**
     * Transfers locked.
     */
    error TransfersLocked();

}

interface IERC1155Soulbound is IERC1155SoulboundFunctions, IERC1155SoulboundSignals { }
