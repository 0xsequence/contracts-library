// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// @title OwnableStorage
/// @author Michael Standen
/// @notice Storage for the ownable module.
library OwnableStorage {

    /// @notice Ownable storage struct
    /// @param owner The owner of the contract
    /// @custom:storage-location erc7201:ownable.data
    struct Data {
        address owner;
    }

    bytes32 private constant STORAGE_SLOT =
        keccak256(abi.encode(uint256(keccak256("ownable.data")) - 1)) & ~bytes32(uint256(0xff));

    /// @notice Get the owner storage from storage
    /// @return data The stored owner data
    function load() internal pure returns (Data storage data) {
        bytes32 slot = STORAGE_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            data.slot := slot
        }
    }

}
