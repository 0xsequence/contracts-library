// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { ModularProxyStorage } from "../ModularProxyStorage.sol";
import { IModularProxyIntrospection, IModule } from "./IModularProxyIntrospection.sol";

/// @title ModularProxyIntrospection
/// @author Michael Standen
/// @notice Introspection module for the modular proxy.
contract ModularProxyIntrospection is IModularProxyIntrospection {

    /// @inheritdoc IModularProxyIntrospection
    function defaultImpl() external view returns (address) {
        return ModularProxyStorage.loadDefaultImpl();
    }

    /// @inheritdoc IModularProxyIntrospection
    function selectorToModule(
        bytes4 selector
    ) external view returns (address) {
        return ModularProxyStorage.load().selectorToModule[selector];
    }

    /// @inheritdoc IModularProxyIntrospection
    function interfaceSupported(
        bytes4 interfaceId
    ) external view returns (bool) {
        return ModularProxyStorage.load().interfaceSupported[interfaceId];
    }

    /// @inheritdoc IModularProxyIntrospection
    function moduleToData(
        address module
    ) external view returns (ModularProxyStorage.ModuleData memory data) {
        return ModularProxyStorage.load().moduleToData[module];
    }

    /// @inheritdoc IModule
    function onAttachModule(
        bytes calldata initData
    ) external override {
        // no-op
    }

    /// @inheritdoc IModule
    function describeCapabilities() external pure returns (ModuleSupport memory support) {
        support.interfaces = new bytes4[](1);
        support.interfaces[0] = type(IModularProxyIntrospection).interfaceId;
        support.selectors = new bytes4[](4);
        support.selectors[0] = IModularProxyIntrospection.defaultImpl.selector;
        support.selectors[1] = IModularProxyIntrospection.selectorToModule.selector;
        support.selectors[2] = IModularProxyIntrospection.interfaceSupported.selector;
        support.selectors[3] = IModularProxyIntrospection.moduleToData.selector;
        return support;
    }

}
