// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { AccessControlStorage } from "./AccessControlStorage.sol";
import { IAccessControl } from "./IAccessControl.sol";

/// @title AccessControlInternal
/// @author Michael Standen
/// @notice Internal features for the access control module.
contract AccessControlInternal {

    bytes32 internal constant _DEFAULT_ADMIN_ROLE = 0x00;

    modifier onlyRole(
        bytes32 role
    ) {
        if (!AccessControlStorage.getHasRole(role, msg.sender)) {
            revert IAccessControl.NoRole(msg.sender, role);
        }
        _;
    }

    function _getHasRole(bytes32 role, address account) internal view returns (bool) {
        return AccessControlStorage.getHasRole(role, account);
    }

    function _setHasRole(bytes32 role, address account, bool hasRole) internal {
        AccessControlStorage.setHasRole(role, account, hasRole);
        if (hasRole) {
            emit IAccessControl.RoleGranted(role, account, msg.sender);
        } else {
            emit IAccessControl.RoleRevoked(role, account, msg.sender);
        }
    }

}
