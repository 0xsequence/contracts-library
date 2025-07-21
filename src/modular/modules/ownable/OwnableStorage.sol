// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// @title OwnableStorage
/// @author Michael Standen
/// @notice Storage for the Ownable module
library OwnableStorage {

    /// @notice Ownable storage struct
    /// @param owner The owner of the contract
    /// @custom:storage-location erc7201:ownable.data
    struct OwnableData {
        address owner;
    }

    bytes32 private constant OWNER_SLOT =
        keccak256(abi.encode(uint256(keccak256("ownable.data")) - 1)) & ~bytes32(uint256(0xff));

    /// @notice Get the owner storage from storage
    /// @return data The stored owner data
    function _getOwnerStorage() private pure returns (OwnableData storage data) {
        bytes32 slot = OWNER_SLOT;
        assembly {
            data.slot := slot
        }
    }

    /// @notice Set the owner
    /// @param owner The owner of the contract
    function setOwner(
        address owner
    ) internal {
        OwnableData storage ownerStorage = _getOwnerStorage();
        ownerStorage.owner = owner;
    }

    /// @notice Get the owner from the storage
    /// @return owner The owner of the contract
    function getOwner() internal view returns (address) {
        OwnableData storage ownerStorage = _getOwnerStorage();
        return ownerStorage.owner;
    }

}
