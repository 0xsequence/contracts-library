// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IModule } from "../../../interfaces/IModule.sol";
import { ModularProxyStorage } from "../ModularProxyStorage.sol";

/// @title IModularProxyIntrospection
/// @author Michael Standen
/// @notice Introspection interface for the ModularProxy module
interface IModularProxyIntrospection is IModule {

    /// @notice Get the default implementation
    /// @return defaultImpl The default implementation
    function defaultImpl() external view returns (address);

    /// @notice Get the module for a selector
    /// @param selector The selector to get the module for
    /// @return module The module for the selector
    function selectorToModule(
        bytes4 selector
    ) external view returns (address);

    /// @notice Get whether an interface is supported
    /// @param interfaceId The interface id to check
    /// @return supported Whether the interface is supported
    function interfaceSupported(
        bytes4 interfaceId
    ) external view returns (bool);

    /// @notice Get the module data for a module
    /// @param module The module to get the data for
    /// @return data The module data
    function moduleToData(
        address module
    ) external view returns (ModularProxyStorage.ModuleData memory data);

}
