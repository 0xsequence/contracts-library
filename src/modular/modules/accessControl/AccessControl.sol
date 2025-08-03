// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IExtension, IExtensionMetadata } from "../../interfaces/IExtensionMetadata.sol";
import { LibBytes } from "../../utils/LibBytes.sol";
import { AccessControlInternal } from "./AccessControlInternal.sol";
import { IAccessControl } from "./IAccessControl.sol";

/// @title AccessControl
/// @author Michael Standen
/// @notice Extension to enable access control.
contract AccessControl is AccessControlInternal, IAccessControl, IExtensionMetadata {

    /// @inheritdoc IAccessControl
    function hasRole(bytes32 role, address account) external view returns (bool) {
        return _getHasRole(role, account);
    }

    /// @inheritdoc IAccessControl
    function grantRole(bytes32 role, address account) external onlyRole(_DEFAULT_ADMIN_ROLE) {
        _setHasRole(role, account, true);
    }

    /// @inheritdoc IAccessControl
    function revokeRole(bytes32 role, address account) external onlyRole(_DEFAULT_ADMIN_ROLE) {
        _setHasRole(role, account, false);
    }

    /// @inheritdoc IExtension
    /// @param initData Encoded address of the default admin
    function onAddExtension(
        bytes calldata initData
    ) external override {
        if (initData.length > 0) {
            address admin;
            (admin,) = LibBytes.readAddress(initData, 0);
            _setHasRole(_DEFAULT_ADMIN_ROLE, admin, true);
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
    function extensionSupport() external pure override returns (ExtensionSupport memory support) {
        support.interfaces = new bytes4[](1);
        support.interfaces[0] = type(IAccessControl).interfaceId;
        support.selectors = new bytes4[](3);
        support.selectors[0] = IAccessControl.hasRole.selector;
        support.selectors[1] = IAccessControl.grantRole.selector;
        support.selectors[2] = IAccessControl.revokeRole.selector;
        return support;
    }

}
