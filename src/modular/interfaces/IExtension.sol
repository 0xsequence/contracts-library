// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// @title IExtension
/// @author Michael Standen
/// @notice Interface for modular contract extensions.
interface IExtension {

    /// @notice Called when the extension is added to the base.
    /// @param initData Unspecified initialisation data.
    function onAddExtension(
        bytes calldata initData
    ) external;

    /// @notice Get the list of interface IDs.
    /// @return interfaces List of interface IDs.
    function supportedInterfaces() external view returns (bytes4[] memory interfaces);

    /// @notice Get the supported selectors.
    /// @return selectors List of supported selectors.
    function supportedSelectors() external view returns (bytes4[] memory selectors);

}
