// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// @title DefaultProxyStorage
/// @author Michael Standen
/// @notice Storage for the default proxy module.
library DefaultProxyStorage {

    /// @notice Extension data storage struct
    /// @param selectors The selectors supported by the extension
    /// @param interfaceIds The interface ids supported by the extension
    struct ExtensionData {
        bytes4[] selectors;
        bytes4[] interfaceIds;
    }

    /// @notice Default implementation storage struct
    /// @param defaultImpl The default implementation
    /// @param selectorToExtension Mapping from function selector to extension address
    /// @param interfaceSupported Mapping from interface id to whether it is supported
    /// @param extensionToData Mapping from extension address to extension data
    /// @custom:storage-location erc7201:defaultProxy.data
    struct Data {
        address defaultImpl;
        mapping(bytes4 => address) selectorToExtension;
        mapping(bytes4 => bool) interfaceSupported;
        mapping(address => ExtensionData) extensionToData;
    }

    bytes32 private constant STORAGE_SLOT =
        keccak256(abi.encode(uint256(keccak256("defaultProxy.data")) - 1)) & ~bytes32(uint256(0xff));

    /// @notice Get the default implementation storage from storage
    /// @return data The stored default implementation data
    function load() internal pure returns (Data storage data) {
        bytes32 slot = STORAGE_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            data.slot := slot
        }
    }

}
