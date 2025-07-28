// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// @title IExtension
/// @author Michael Standen
/// @notice Interface for modular contract extensions.
interface IExtension {

    /// @notice Supported features of an extension.
    /// @param interfaces List of supported interface IDs.
    /// @param selectors List of supported selectors.
    struct ExtensionSupport {
        bytes4[] interfaces;
        bytes4[] selectors;
    }

    /// @notice Get the supported features.
    /// @return support The supported features.
    function extensionSupport() external view returns (ExtensionSupport memory support);

    /// @notice Called when the extension is added to the base.
    /// @param initData Unspecified initialisation data.
    function onAddExtension(
        bytes calldata initData
    ) external;

}
