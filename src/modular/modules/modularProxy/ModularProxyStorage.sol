// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// @title ModularProxyStorage
/// @author Michael Standen
/// @notice Storage for the modular proxy module.
library ModularProxyStorage {

    /// @notice Extension data storage struct
    /// @param selectors The selectors supported by the extension
    /// @param interfaceIds The interface ids supported by the extension
    struct ExtensionData {
        bytes4[] selectors;
        bytes4[] interfaceIds;
    }

    /// @notice Default implementation storage struct
    /// @param selectorToExtension Mapping from function selector to extension address
    /// @param interfaceSupported Mapping from interface id to whether it is supported
    /// @param extensionToData Mapping from extension address to extension data
    /// @custom:storage-location erc7201:modularProxy.data
    struct Data {
        mapping(bytes4 => address) selectorToExtension;
        mapping(bytes4 => bool) interfaceSupported;
        mapping(address => ExtensionData) extensionToData;
    }

    bytes32 private constant DEFAULT_IMPL_SLOT =
        keccak256(abi.encode("eip1967.proxy.implementation")) & ~bytes32(uint256(0xff));

    bytes32 private constant STORAGE_SLOT =
        keccak256(abi.encode(uint256(keccak256("modularProxy.data")) - 1)) & ~bytes32(uint256(0xff));

    /// @notice Get the default implementation storage from storage
    /// @return data The stored default implementation data
    function load() internal pure returns (Data storage data) {
        bytes32 slot = STORAGE_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            data.slot := slot
        }
    }

    /// @notice Load the default implementation from storage
    /// @return defaultImpl The default implementation
    function loadDefaultImpl() internal view returns (address defaultImpl) {
        bytes32 slot = DEFAULT_IMPL_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            defaultImpl := sload(slot)
        }
    }

    /// @notice Store the default implementation in storage
    /// @param defaultImpl The default implementation
    function storeDefaultImpl(
        address defaultImpl
    ) internal {
        bytes32 slot = DEFAULT_IMPL_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            sstore(slot, defaultImpl)
        }
    }

}
