// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// @title IERC165
/// @notice Interface of the ERC165 standard
interface IERC165 {

    /// @notice Returns true if this contract implements the interface defined by `interfaceId`.
    /// @param interfaceId The interface id to check
    /// @return supported Whether the interface is supported
    function supportsInterface(
        bytes4 interfaceId
    ) external view returns (bool);

}
