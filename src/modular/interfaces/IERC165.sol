// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// @title IERC165
/// @author Michael Standen
/// @notice Interface of the ERC165 standard
/// @dev This interface intentionally has no view modifier to allow for dynamic support of interfaces
interface IERC165 {

    /// @notice Returns true if this contract implements the interface defined by `interfaceId`.
    /// @param interfaceId The interface id to check
    /// @return supported Whether the interface is supported
    function supportsInterface(
        bytes4 interfaceId
    ) external returns (bool);

}
