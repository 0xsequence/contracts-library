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
        DefaultProxyStorage.setDefaultImpl(defaultImpl);
    }

    /// @inheritdoc IBase
    function addExtension(IExtension extension, bytes calldata initData) external override onlyOwner {
        DefaultProxyStorage.addExtension(extension);
        extension.onAddExtension(initData);
        emit ExtensionAdded(extension);
    }

    /// @inheritdoc IBase
    function removeExtension(
        IExtension extension
    ) external override onlyOwner {
        DefaultProxyStorage.removeExtension(extension);
        emit ExtensionRemoved(extension);
    }

    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) public virtual returns (bool) {
        bool supported = DefaultProxyStorage.interfaceSupported(interfaceId) || interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IBase).interfaceId;
        if (!supported) {
            try IERC165(DefaultProxyStorage.getDefaultImpl()).supportsInterface(interfaceId) returns (
                bool defaultSupported
            ) {
                return defaultSupported;
            } catch {
                return false;
            }
        }
        return supported;
    }

    function _delegateCall(
        address implementation
    ) internal {
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
    fallback() external payable {
        address implementation = DefaultProxyStorage.getExtensionForSelector(msg.sig);
        if (implementation == address(0)) {
            implementation = DefaultProxyStorage.getDefaultImpl();
        }
        _delegateCall(implementation);
    }

    /// @notice Receive function to handle ETH transfers
    receive() external payable { }

}
