// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// @title AccessControlStorage
/// @author Michael Standen
/// @notice Storage for the access control module.
library AccessControlStorage {

    /// @notice AccessControl storage struct
    /// @param roleAccounts The accounts that have the role
    /// @custom:storage-location erc7201:accessControl.data
    struct Data {
        mapping(bytes32 role => mapping(address account => bool hasRole)) roleAccounts;
    }

    bytes32 private constant STORAGE_SLOT =
        keccak256(abi.encode(uint256(keccak256("accessControl.data")) - 1)) & ~bytes32(uint256(0xff));

    /// @notice Get the access control storage from storage
    /// @return data The stored access control data
    function load() private pure returns (Data storage data) {
        bytes32 slot = STORAGE_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            data.slot := slot
        }
    }

    /// @notice Checks if the account has the role
    /// @param role The role to check
    /// @param account The account to check
    /// @return hasRole Whether the account has the role
    function getHasRole(bytes32 role, address account) internal view returns (bool) {
        Data storage data = load();
        return data.roleAccounts[role][account];
    }

    /// @notice Sets the role for an account
    /// @param role The role to set
    /// @param account The account to set the role for
    /// @param hasRole Whether the account has the role
    function setHasRole(bytes32 role, address account, bool hasRole) internal {
        Data storage data = load();
        data.roleAccounts[role][account] = hasRole;
    }

}
