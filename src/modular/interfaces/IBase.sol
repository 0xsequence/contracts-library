// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IExtension } from "./IExtension.sol";

/// @title IBase
/// @author Michael Standen
/// @notice Base interface for the modular contract proxy.
interface IBase {

    /// @notice Emitted when an extension is added.
    /// @param extension The extension that was added.
    event ExtensionAdded(IExtension extension);

    /// @notice Emitted when an extension is removed.
    /// @param extension The extension that was removed.
    event ExtensionRemoved(IExtension extension);

    /// @notice Add an extension.
    /// @param extension The extension to add.
    /// @param initData The data to initialize the extension with.
    function addExtension(IExtension extension, bytes calldata initData) external;

    /// @notice Remove an extension.
    /// @param extension The extension to remove.
    function removeExtension(
        IExtension extension
    ) external;

}
