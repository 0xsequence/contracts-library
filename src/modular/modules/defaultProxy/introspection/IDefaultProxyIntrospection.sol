// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IExtension } from "../../../interfaces/IExtension.sol";
import { DefaultProxyStorage } from "../DefaultProxyStorage.sol";

/// @title IDefaultProxyIntrospection
/// @author Michael Standen
/// @notice Introspection interface for the DefaultProxy module
interface IDefaultProxyIntrospection is IExtension {

    /// @notice Get the default implementation
    /// @return defaultImpl The default implementation
    function defaultImpl() external view returns (address);

    /// @notice Get the extension for a selector
    /// @param selector The selector to get the extension for
    /// @return extension The extension for the selector
    function selectorToExtension(
        bytes4 selector
    ) external view returns (address);

    /// @notice Get whether an interface is supported
    /// @param interfaceId The interface id to check
    /// @return supported Whether the interface is supported
    function interfaceSupported(
        bytes4 interfaceId
    ) external view returns (bool);

    /// @notice Get the extension data for an extension
    /// @param extension The extension to get the data for
    /// @return data The extension data
    function extensionToData(
        address extension
    ) external view returns (DefaultProxyStorage.ExtensionData memory data);

}
