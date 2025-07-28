// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IExtension, IExtensionMetadata } from "../../interfaces/IExtensionMetadata.sol";
import { AccessControlInternal } from "./AccessControlInternal.sol";
import { AccessControlStorage } from "./AccessControlStorage.sol";
import { IAccessControl } from "./IAccessControl.sol";

/// @title AccessControl
/// @author Michael Standen
/// @notice Extension to enable access control.
contract AccessControl is AccessControlInternal, IAccessControl, IExtensionMetadata {

    /// @inheritdoc IAccessControl
    function hasRole(bytes32 role, address account) external view returns (bool) {
        return AccessControlStorage.getHasRole(role, account);
    }

    /// @inheritdoc IAccessControl
    function grantRole(bytes32 role, address account) external onlyRole(_DEFAULT_ADMIN_ROLE) {
        AccessControlStorage.setHasRole(role, account, true);
        emit IAccessControl.RoleGranted(role, account, msg.sender);
    }

    /// @inheritdoc IAccessControl
    function revokeRole(bytes32 role, address account) external onlyRole(_DEFAULT_ADMIN_ROLE) {
        AccessControlStorage.setHasRole(role, account, false);
        emit IAccessControl.RoleRevoked(role, account, msg.sender);
    }

    /// @inheritdoc IExtension
    /// @param initData Encoded address of the default admin
    function onAddExtension(
        bytes calldata initData
    ) external override {
        if (initData.length > 0) {
            (address admin) = abi.decode(initData, (address));
            AccessControlStorage.setHasRole(_DEFAULT_ADMIN_ROLE, admin, true);
            emit IAccessControl.RoleGranted(_DEFAULT_ADMIN_ROLE, admin, msg.sender);
        }
    }

    /// @inheritdoc IExtensionMetadata
    function getMetadata() external pure override returns (ExtensionMetadata memory metadata) {
        return ExtensionMetadata({
            name: "AccessControl",
            version: "1.0.0",
            description: "AccessControl module",
            author: "Sequence",
            url: "https://github.com/0xsequence/contracts-library.git"
        });
    }

    /// @inheritdoc IExtension
    function supportedSelectors() external pure override returns (bytes4[] memory selectors) {
        selectors = new bytes4[](3);
        selectors[0] = IAccessControl.hasRole.selector;
        selectors[1] = IAccessControl.grantRole.selector;
        selectors[2] = IAccessControl.revokeRole.selector;
        return selectors;
    }

    /// @inheritdoc IExtension
    function supportedInterfaces() external pure override returns (bytes4[] memory interfaceIds) {
        interfaceIds = new bytes4[](1);
        interfaceIds[0] = type(IAccessControl).interfaceId;
        return interfaceIds;
    }

}
