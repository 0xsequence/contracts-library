// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IModule } from "./IModule.sol";

/// @title IModularBase
/// @author Michael Standen
/// @notice Base interface for the modular contract proxy.
interface IModularBase {

    /// @notice Emitted when a module is added.
    /// @param module The module that was added.
    event ModuleAdded(IModule module);

    /// @notice Emitted when a module is removed.
    /// @param module The module that was removed.
    event ModuleRemoved(IModule module);

    /// @notice Attach a module.
    /// @param module The module to attach.
    /// @param initData The data to initialize the module with.
    function attachModule(IModule module, bytes calldata initData) external;

    /// @notice Detach a module.
    /// @param module The module to detach.
    function detachModule(
        IModule module
    ) external;

}
