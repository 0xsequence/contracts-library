// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IERC721SoulboundFunctions {
    /**
     * Sets the transfer lock.
     * @param locked Whether or not transfers are locked.
     */
    function setTransferLocked(bool locked) external;

    /**
     * Gets the transfer lock.
     * @return Whether or not transfers are locked.
     */
    function getTransferLocked() external view returns (bool);
}

interface IERC721SoulboundSignals {
    /**
     * Transfers locked.
     */
    error TransfersLocked();
}

interface IERC721Soulbound is IERC721SoulboundFunctions, IERC721SoulboundSignals {}
