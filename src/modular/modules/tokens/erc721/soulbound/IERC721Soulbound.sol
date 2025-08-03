// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// @title IERC721Soulbound
/// @author Michael Standen
/// @notice Interface for the ERC721Soulbound module
interface IERC721Soulbound {

    error TransfersLocked();

    /// @notice Set the transfer lock
    /// @param locked Whether transfers are locked
    function setTransferLocked(
        bool locked
    ) external;

    /// @notice Get the transfer lock
    /// @return locked Whether transfers are locked
    function getTransferLocked() external view returns (bool locked);

}
