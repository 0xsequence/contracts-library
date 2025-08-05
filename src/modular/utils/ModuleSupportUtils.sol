// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IModule } from "../interfaces/IModule.sol";

/// @title ModuleSupportUtils
/// @author Michael Standen
/// @notice Utility functions for module support
library ModuleSupportUtils {

    /// @notice Flattens an array of module supports into a single module support
    /// @param supers The array of module supports to flatten
    /// @return support The flattened module support
    function flatten(
        IModule.ModuleSupport[] memory supers
    ) internal pure returns (IModule.ModuleSupport memory support) {
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
