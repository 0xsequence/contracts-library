// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IExtension } from "./IExtension.sol";

/// @title IExtensionMetadata
/// @author Michael Standen
/// @notice Extension metadata interface.
interface IExtensionMetadata is IExtension {

    /// @notice Extension metadata structure
    /// @param name Human-readable name of the extension
    /// @param version Version of the extension (e.g., "1.0.0")
    /// @param description Description of what the extension does
    /// @param author Author/developer of the extension
    /// @param url URL to documentation or source code
    struct ExtensionMetadata {
        string name;
        string version;
        string description;
        string author;
        string url;
    }

    /// @notice Get the extension metadata.
    /// @return metadata Extension metadata containing name, version, description, etc.
    function getMetadata() external view returns (ExtensionMetadata memory metadata);

}
