// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// @title IAccessControl
/// @author Michael Standen
/// @notice Interface for the access control module.
interface IAccessControl {

    /// @notice Emitted when the role is granted
    event RoleGranted(bytes32 role, address account, address sender);

    /// @notice Emitted when the role is revoked
    event RoleRevoked(bytes32 role, address account, address sender);

    /// @notice Thrown when the caller is not the role
    error NoRole(address account, bytes32 role);

    /// @notice Checks if the account has the role
    /// @param role The role to check
    /// @param account The account to check
    /// @return hasRole Whether the account has the role
    function hasRole(bytes32 role, address account) external view returns (bool);

    /// @notice Grants a role to an account
    /// @param role The role to grant
    /// @param account The account to grant the role to
    function grantRole(bytes32 role, address account) external;

    /// @notice Revokes a role from an account
    /// @param role The role to revoke
    /// @param account The account to revoke the role from
    function revokeRole(bytes32 role, address account) external;

}
