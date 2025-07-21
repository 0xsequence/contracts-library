// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IExtension } from "./IExtension.sol";

/// @title IBase
/// @author Michael Standen
/// @notice Base interface.
interface IBase {

    /// @notice Emitted when an extension is added.
    /// @param extension The extension that was added.
    event ExtensionAdded(IExtension extension);

    /// @notice Emitted when an extension is removed.
    /// @param extension The extension that was removed.
    event ExtensionRemoved(IExtension extension);

    /// @notice Thrown when a call is made to the contract for a selector that is not assigned.
    /// @param selector The selector that is not assigned.
    error SelectorNotAssigned(bytes4 selector);

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
