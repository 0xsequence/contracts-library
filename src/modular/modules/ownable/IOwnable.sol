// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// @title IOwnable
/// @author Michael Standen
/// @notice Interface for the ownable module.
interface IOwnable {

    /// @notice Emitted when the ownership of the contract is transferred
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /// @notice Thrown when the caller is not the owner
    error CallerIsNotOwner();

    /// @notice Get the owner of the contract
    /// @return owner The owner of the contract
    function owner() external view returns (address);

    /// @notice Transfer ownership of the contract to a new account
    /// @param newOwner The new owner of the contract
    function transferOwnership(
        address newOwner
    ) external;

}
