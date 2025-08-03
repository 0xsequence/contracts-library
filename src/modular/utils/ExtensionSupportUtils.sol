// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IExtension } from "../interfaces/IExtension.sol";

/// @title ExtensionSupportUtils
/// @author Michael Standen
/// @notice Utility functions for extension support
library ExtensionSupportUtils {

    /// @notice Flattens an array of extension supports into a single extension support
    /// @param supers The array of extension supports to flatten
    /// @return support The flattened extension support
    function flatten(
        IExtension.ExtensionSupport[] memory supers
    ) internal pure returns (IExtension.ExtensionSupport memory support) {
        // Determine the total number of interfaces and selectors
        uint256 nInterfaces = 0;
        uint256 nSelectors = 0;
        for (uint256 i = 0; i < supers.length; i++) {
            nInterfaces += supers[i].interfaces.length;
            nSelectors += supers[i].selectors.length;
        }
        support.interfaces = new bytes4[](nInterfaces);
        support.selectors = new bytes4[](nSelectors);

        // Flatten the interfaces and selectors
        nInterfaces = 0;
        nSelectors = 0;
        for (uint256 i = 0; i < supers.length; i++) {
            for (uint256 j = 0; j < supers[i].interfaces.length; j++) {
                support.interfaces[nInterfaces] = supers[i].interfaces[j];
                nInterfaces++;
            }
            for (uint256 j = 0; j < supers[i].selectors.length; j++) {
                support.selectors[nSelectors] = supers[i].selectors[j];
                nSelectors++;
            }
        }

        return support;
    }

}
