// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { DefaultProxyStorage } from "../DefaultProxyStorage.sol";
import { IDefaultProxyIntrospection, IExtension } from "./IDefaultProxyIntrospection.sol";

/// @title DefaultProxyIntrospection
/// @author Michael Standen
/// @notice Introspection module for the default proxy.
contract DefaultProxyIntrospection is IDefaultProxyIntrospection {

    /// @inheritdoc IDefaultProxyIntrospection
    function defaultImpl() external view returns (address) {
        return DefaultProxyStorage.load().defaultImpl;
    }

    /// @inheritdoc IDefaultProxyIntrospection
    function selectorToExtension(
        bytes4 selector
    ) external view returns (address) {
        return DefaultProxyStorage.load().selectorToExtension[selector];
    }

    /// @inheritdoc IDefaultProxyIntrospection
    function interfaceSupported(
        bytes4 interfaceId
    ) external view returns (bool) {
        return DefaultProxyStorage.load().interfaceSupported[interfaceId];
    }

    /// @inheritdoc IDefaultProxyIntrospection
    function extensionToData(
        address extension
    ) external view returns (DefaultProxyStorage.ExtensionData memory data) {
        return DefaultProxyStorage.load().extensionToData[extension];
    }

    /// @inheritdoc IExtension
    function onAddExtension(
        bytes calldata initData
    ) external override {
        // no-op
    }

    /// @inheritdoc IExtension
    function extensionSupport() external pure returns (ExtensionSupport memory support) {
        support.interfaces = new bytes4[](1);
        support.interfaces[0] = type(IDefaultProxyIntrospection).interfaceId;
        support.selectors = new bytes4[](4);
        support.selectors[0] = IDefaultProxyIntrospection.defaultImpl.selector;
        support.selectors[1] = IDefaultProxyIntrospection.selectorToExtension.selector;
        support.selectors[2] = IDefaultProxyIntrospection.interfaceSupported.selector;
        support.selectors[3] = IDefaultProxyIntrospection.extensionToData.selector;
        return support;
    }

}
