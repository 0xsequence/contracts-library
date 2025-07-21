// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IBase, IExtension } from "../../interfaces/IBase.sol";
import { DefaultProxyStorage } from "./DefaultProxyStorage.sol";

import { IERC165 } from "../../interfaces/IERC165.sol";
import { OwnablePrivate } from "../../modules/ownable/OwnablePrivate.sol";

/// @title DefaultProxy
/// @author Michael Standen
/// @notice Proxy that delegates all calls to configured extensions or the default implementation
/// @dev This contract supports ERC165 even though it does not inherit the interface here
contract DefaultProxy is IBase, IERC165, OwnablePrivate {

    /// @notice Constructor
    /// @param defaultImpl The default implementation of the proxy
    constructor(address defaultImpl, address owner) {
        _transferOwnership(owner);
        DefaultProxyStorage.load().defaultImpl = defaultImpl;
    }

    /// @inheritdoc IBase
    function addExtension(IExtension extension, bytes calldata initData) external override onlyOwner {
        address extensionAddress = address(extension);

        DefaultProxyStorage.Data storage data = DefaultProxyStorage.load();

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
            DefaultProxyStorage.ExtensionData({ selectors: selectors, interfaceIds: interfaceIds });

        extension.onAddExtension(initData);
        emit ExtensionAdded(extension);
    }

    /// @inheritdoc IBase
    function removeExtension(
        IExtension extension
    ) external override onlyOwner {
        DefaultProxyStorage.Data storage data = DefaultProxyStorage.load();
        address extensionAddress = address(extension);

        // Remove all selectors for this extension
        bytes4[] memory selectors = data.extensionToData[extensionAddress].selectors;
        for (uint256 i = 0; i < selectors.length; i++) {
            delete data.selectorToExtension[selectors[i]];
        }

        // Remove all interface ids for this extension
        bytes4[] memory interfaceIds = data.extensionToData[extensionAddress].interfaceIds;
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            delete data.interfaceSupported[interfaceIds[i]];
        }

        delete data.extensionToData[extensionAddress];

        emit ExtensionRemoved(extension);
    }

    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) public virtual returns (bool) {
        // Base supported interfaces
        bool supported = interfaceId == type(IERC165).interfaceId || interfaceId == type(IBase).interfaceId;
        if (supported) {
            return true;
        }

        // Extension supported interfaces
        DefaultProxyStorage.Data storage data = DefaultProxyStorage.load();
        supported = data.interfaceSupported[interfaceId];
        if (supported) {
            return true;
        }

        // Default implementation supported interfaces
        try IERC165(data.defaultImpl).supportsInterface(interfaceId) returns (bool defaultSupported) {
            return defaultSupported;
        } catch { }
        return false;
    }

    function _delegateCall(
        address implementation
    ) internal {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let ok := delegatecall(gas(), implementation, ptr, calldatasize(), 0, 0)
            let sz := returndatasize()
            returndatacopy(ptr, 0, sz)
            if iszero(ok) { revert(ptr, sz) }
            return(ptr, sz)
        }
    }

    /// @notice Fallback function to route calls to extensions or the default implementation
    /// @dev This function is called when no other function matches the call
    // solhint-disable-next-line no-complex-fallback
    fallback() external payable {
        DefaultProxyStorage.Data storage data = DefaultProxyStorage.load();
        address implementation = data.selectorToExtension[msg.sig];
        if (implementation == address(0)) {
            implementation = data.defaultImpl;
        }
        _delegateCall(implementation);
    }

    /// @notice Receive function to handle ETH transfers
    receive() external payable { }

}
