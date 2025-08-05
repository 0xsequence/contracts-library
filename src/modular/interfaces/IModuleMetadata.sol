// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IModule } from "./IModule.sol";

/// @title IModuleMetadata
/// @author Michael Standen
/// @notice Extended metadata interface for modular contract modules.
interface IModuleMetadata is IModule {

    /// @notice Module metadata structure
    /// @param name Human-readable name of the module
    /// @param version Version of the module (e.g., "1.0.0")
    /// @param description Description of what the module does
    /// @param author Author/developer of the module
    /// @param url URL to documentation or source code
    struct ModuleMetadata {
        string name;
        string version;
        string description;
        string author;
        string url;
    }

    /// @notice Get the module metadata.
    /// @return metadata Module metadata containing name, version, description, etc.
    function getMetadata() external view returns (ModuleMetadata memory metadata);

}
