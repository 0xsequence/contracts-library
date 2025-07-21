// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { DefaultProxyStorage } from "../DefaultProxyStorage.sol";
import { IDefaultProxyIntrospection, IExtension } from "./IDefaultProxyIntrospection.sol";

/// @title DefaultProxyIntrospection
/// @author Michael Standen
/// @notice Introspection module for the DefaultProxy storage
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
    function supportedInterfaces() external pure returns (bytes4[] memory) {
        bytes4[] memory interfaces = new bytes4[](1);
        interfaces[0] = type(IDefaultProxyIntrospection).interfaceId;
        return interfaces;
    }

    /// @inheritdoc IExtension
    function supportedSelectors() external pure returns (bytes4[] memory) {
        bytes4[] memory selectors = new bytes4[](4);
        selectors[0] = IDefaultProxyIntrospection.defaultImpl.selector;
        selectors[1] = IDefaultProxyIntrospection.selectorToExtension.selector;
        selectors[2] = IDefaultProxyIntrospection.interfaceSupported.selector;
        selectors[3] = IDefaultProxyIntrospection.extensionToData.selector;
        return selectors;
    }

}
