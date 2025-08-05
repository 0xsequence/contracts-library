// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// @title IModule
/// @author Michael Standen
/// @notice Interface for modular contract modules.
interface IModule {

    /// @notice Supported features of a module.
    /// @param interfaces List of supported interface IDs.
    /// @param selectors List of supported selectors.
    struct ModuleSupport {
        bytes4[] interfaces;
        bytes4[] selectors;
    }

    /// @notice Get the supported features.
    /// @return support The supported features.
    function describeCapabilities() external view returns (ModuleSupport memory support);

    /// @notice Called when the module is attached to the base.
    /// @param initData Unspecified initialisation data.
    function onAttachModule(
        bytes calldata initData
    ) external;

}
