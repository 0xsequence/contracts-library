// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IERC165 } from "../../interfaces/IERC165.sol";
import { IModularBase, IModule } from "../../interfaces/IModularBase.sol";
import { OwnableInternal } from "../../modules/ownable/OwnableInternal.sol";
import { ModularProxyStorage } from "./ModularProxyStorage.sol";

/// @title ModularProxy
/// @author Michael Standen
/// @notice Proxy that delegates all calls to configured modules or the default implementation
contract ModularProxy is IModularBase, IERC165, OwnableInternal {

    /// @notice Error thrown when attaching a module fails
    error AttachModuleFailed(address module);

    /// @notice Constructor
    /// @param defaultImpl The default implementation of the proxy
    constructor(address defaultImpl, address owner) {
        _transferOwnership(owner);
        ModularProxyStorage.storeDefaultImpl(defaultImpl);
    }

    /// @inheritdoc IModularBase
    function attachModule(IModule module, bytes calldata initData) external override onlyOwner {
        address moduleAddress = address(module);

        ModularProxyStorage.Data storage data = ModularProxyStorage.load();

        // Register all supported selectors and interface ids for this module
        IModule.ModuleSupport memory support = module.describeCapabilities();
        for (uint256 i = 0; i < support.selectors.length; i++) {
            data.selectorToModule[support.selectors[i]] = moduleAddress;
        }
        for (uint256 i = 0; i < support.interfaces.length; i++) {
            data.interfaceSupported[support.interfaces[i]] = true;
        }
        data.moduleToData[moduleAddress] =
            ModularProxyStorage.ModuleData({ selectors: support.selectors, interfaceIds: support.interfaces });

        // solhint-disable avoid-low-level-calls
        (bool success,) =
            address(module).delegatecall(abi.encodeWithSelector(IModule.onAttachModule.selector, initData));
        if (!success) {
            revert AttachModuleFailed(moduleAddress);
        }

        emit ModuleAdded(module);
    }

    /// @inheritdoc IModularBase
    function detachModule(
        IModule module
    ) external override onlyOwner {
        ModularProxyStorage.Data storage data = ModularProxyStorage.load();
        address moduleAddress = address(module);

        // Remove all selectors for this module
        bytes4[] memory selectors = data.moduleToData[moduleAddress].selectors;
        for (uint256 i = 0; i < selectors.length; i++) {
            delete data.selectorToModule[selectors[i]];
        }

        // Remove all interface ids for this module
        bytes4[] memory interfaceIds = data.moduleToData[moduleAddress].interfaceIds;
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            delete data.interfaceSupported[interfaceIds[i]];
        }

        delete data.moduleToData[moduleAddress];

        emit ModuleRemoved(module);
    }

    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual returns (bool) {
        // Base supported interfaces
        bool supported = interfaceId == type(IERC165).interfaceId || interfaceId == type(IModularBase).interfaceId;
        if (supported) {
            return true;
        }

        // Module supported interfaces
        ModularProxyStorage.Data storage data = ModularProxyStorage.load();
        supported = data.interfaceSupported[interfaceId];
        if (supported) {
            return true;
        }

        // Default implementation supported interfaces
        address defaultImpl = ModularProxyStorage.loadDefaultImpl();
        try IERC165(defaultImpl).supportsInterface(interfaceId) returns (bool defaultSupported) {
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

    /// @notice Fallback function to route calls to modules or the default implementation
    /// @dev This function is called when no other function matches the call
    // solhint-disable-next-line no-complex-fallback
    fallback() external payable {
        ModularProxyStorage.Data storage data = ModularProxyStorage.load();
        address implementation = data.selectorToModule[msg.sig];
        if (implementation == address(0)) {
            implementation = ModularProxyStorage.loadDefaultImpl();
        }
        _delegateCall(implementation);
    }

    /// @notice Receive function to handle ETH transfers
    receive() external payable { }

}
