// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IExtension, IExtensionMetadata } from "../../interfaces/IExtensionMetadata.sol";
import { IOwnable } from "./IOwnable.sol";
import { OwnablePrivate } from "./OwnablePrivate.sol";
import { OwnableStorage } from "./OwnableStorage.sol";

/// @title Ownable
/// @author Michael Standen
/// @notice Ownable module
contract Ownable is OwnablePrivate, IOwnable, IExtensionMetadata {

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

    /// @inheritdoc IExtension
    function onAddExtension(
        bytes calldata initData
    ) external pure override {
        // no-op
    }

    /// @inheritdoc IExtensionMetadata
    function getMetadata() external pure override returns (ExtensionMetadata memory metadata) {
        return ExtensionMetadata({
            name: "Ownable",
            version: "1.0.0",
            description: "Ownable module",
            author: "Sequence",
            url: "https://github.com/0xsequence/contracts-library.git"
        });
    }

    /// @inheritdoc IExtension
    function supportedSelectors() external pure override returns (bytes4[] memory selectors) {
        selectors = new bytes4[](2);
        selectors[0] = IOwnable.owner.selector;
        selectors[1] = IOwnable.transferOwnership.selector;
        return selectors;
    }

    /// @inheritdoc IExtension
    function supportedInterfaces() external pure override returns (bytes4[] memory interfaceIds) {
        interfaceIds = new bytes4[](1);
        interfaceIds[0] = type(IOwnable).interfaceId;
        return interfaceIds;
    }

}
