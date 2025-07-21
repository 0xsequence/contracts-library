// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IBase } from "../../interfaces/IBase.sol";
import { IExtension } from "../../interfaces/IExtension.sol";

/// @title DefaultProxyStorage
/// @author Michael Standen
/// @notice Storage for the DefaultProxy module
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
    struct DefaultProxyData {
        address defaultImpl;
        mapping(bytes4 => address) selectorToExtension;
        mapping(bytes4 => bool) interfaceSupported;
        mapping(address => ExtensionData) extensionToData;
    }

    bytes32 private constant DEFAULT_IMPL_SLOT =
        keccak256(abi.encode(uint256(keccak256("defaultProxy.data")) - 1)) & ~bytes32(uint256(0xff));

    /// @notice Get the default implementation storage from storage
    /// @return data The stored default implementation data
    function _getDefaultProxyData() private pure returns (DefaultProxyData storage data) {
        bytes32 slot = DEFAULT_IMPL_SLOT;
        assembly {
            data.slot := slot
        }
    }

    /// @notice Set the default implementation
    /// @param defaultImpl The default implementation
    function setDefaultImpl(
        address defaultImpl
    ) internal {
        DefaultProxyData storage defaultImplStorage = _getDefaultProxyData();
        defaultImplStorage.defaultImpl = defaultImpl;
    }

    /// @notice Get the default implementation from the storage
    /// @return defaultImpl The default implementation
    function getDefaultImpl() internal view returns (address) {
        DefaultProxyData storage defaultImplStorage = _getDefaultProxyData();
        return defaultImplStorage.defaultImpl;
    }

    /// @notice Add an extension to the selector storage
    /// @param extension The extension to add
    function addExtension(
        IExtension extension
    ) internal {
        DefaultProxyData storage data = _getDefaultProxyData();
        address extensionAddress = address(extension);

        // Register all supported selectors and interface ids for this extension
        bytes4[] memory selectors = extension.supportedSelectors();
        for (uint256 i = 0; i < selectors.length; i++) {
            data.selectorToExtension[selectors[i]] = extensionAddress;
        }
        bytes4[] memory interfaceIds = extension.supportedInterfaces();
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            data.interfaceSupported[interfaceIds[i]] = true;
        }

        data.extensionToData[extensionAddress] =
            ExtensionData({ selectors: selectors, interfaceIds: extension.supportedInterfaces() });
    }

    /// @notice Remove an extension from the selector storage
    /// @param extension The extension to remove
    function removeExtension(
        IExtension extension
    ) internal {
        DefaultProxyData storage data = _getDefaultProxyData();
        address extensionAddress = address(extension);

        // Remove all selectors for this extension
        ExtensionData memory extensionData = data.extensionToData[extensionAddress];
        bytes4[] memory selectors = extensionData.selectors;
        for (uint256 i = 0; i < selectors.length; i++) {
            bytes4 selector = selectors[i];

            delete data.selectorToExtension[selector];
        }

        // Remove all interface ids for this extension
        bytes4[] memory interfaceIds = extensionData.interfaceIds;
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            bytes4 interfaceId = interfaceIds[i];
            delete data.interfaceSupported[interfaceId];
        }

        delete data.extensionToData[extensionAddress];
    }

    /// @notice Get the extension address for a given selector from the selector storage
    /// @param selector The function selector
    /// @return extensionAddress The address of the extension that handles this selector
    function getExtensionForSelector(
        bytes4 selector
    ) internal view returns (address extensionAddress) {
        DefaultProxyData storage data = _getDefaultProxyData();
        return data.selectorToExtension[selector];
    }

    /// @notice Check if an interface is supported by an extension
    /// @param interfaceId The interface id to check
    /// @return supported Whether the interface is supported
    function interfaceSupported(
        bytes4 interfaceId
    ) internal view returns (bool) {
        DefaultProxyData storage data = _getDefaultProxyData();
        return data.interfaceSupported[interfaceId];
    }

}
