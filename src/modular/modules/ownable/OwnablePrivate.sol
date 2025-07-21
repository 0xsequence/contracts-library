// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IOwnable } from "./IOwnable.sol";
import { OwnableStorage } from "./OwnableStorage.sol";

/// @title OwnablePrivate
/// @author Michael Standen
/// @notice Implementation of ownable that does not expose the interface
contract OwnablePrivate {

    function _transferOwnership(
        address newOwner
    ) internal {
        OwnableStorage.Data storage data = OwnableStorage.load();
        address oldOwner = data.owner;
        data.owner = newOwner;
        emit IOwnable.OwnershipTransferred(oldOwner, newOwner);
    }

    /// @notice Modifier to check if the caller is the owner
    /// @dev This modifier is used to restrict access to functions that can only be called by the owner
    modifier onlyOwner() {
        OwnableStorage.Data storage data = OwnableStorage.load();
        if (data.owner != msg.sender) {
            revert IOwnable.CallerIsNotOwner();
        }
        _;
    }

}
