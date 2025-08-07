// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IModule, IModuleMetadata } from "../../interfaces/IModuleMetadata.sol";
import { IOwnable } from "./IOwnable.sol";
import { OwnableInternal } from "./OwnableInternal.sol";
import { OwnableStorage } from "./OwnableStorage.sol";

/// @title Ownable
/// @author Michael Standen
/// @notice Module to enable contract-level ownership.
contract Ownable is OwnableInternal, IOwnable, IModuleMetadata {

    /// @inheritdoc IOwnable
    function owner() public view virtual returns (address) {
        OwnableStorage.Data storage data = OwnableStorage.load();
        return data.owner;
    }

    /// @inheritdoc IOwnable
    function transferOwnership(
        address newOwner
    ) external virtual onlyOwner {
        _transferOwnership(newOwner);
    }

    /// @inheritdoc IModule
    /// @param initData Encoded address of the new owner
    function onAttachModule(
        bytes calldata initData
    ) external override {
        if (initData.length > 0) {
            (address newOwner) = abi.decode(initData, (address));
            _transferOwnership(newOwner);
        }
    }

    /// @inheritdoc IModuleMetadata
    function getMetadata() external pure override returns (ModuleMetadata memory metadata) {
        metadata.name = "Ownable";
        metadata.version = "1.0.0";
        metadata.description = "Enable contract-level ownership";
        metadata.author = "Sequence";
        metadata.url = "https://github.com/0xsequence/contracts-library.git";
    }

    /// @inheritdoc IModule
    function describeCapabilities() external pure override returns (ModuleSupport memory support) {
        support.interfaces = new bytes4[](1);
        support.interfaces[0] = type(IOwnable).interfaceId;
        support.selectors = new bytes4[](2);
        support.selectors[0] = IOwnable.owner.selector;
        support.selectors[1] = IOwnable.transferOwnership.selector;
        return support;
    }

}
