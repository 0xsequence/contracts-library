// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// @title ERC721SoulboundStorage
/// @author Michael Standen
/// @notice Storage for the ERC721Soulbound module.
library ERC721SoulboundStorage {

    /// @notice ERC721Soulbound storage struct
    /// @param transferLocked Whether transfers are locked
    /// @custom:storage-location erc7201:erc721soulbound.data
    struct Data {
        bool transferLocked;
    }

    bytes32 private constant STORAGE_SLOT =
        keccak256(abi.encode(uint256(keccak256("erc721soulbound.data")) - 1)) & ~bytes32(uint256(0xff));

    /// @notice Get the storage from storage
    /// @return data The stored data
    function load() internal pure returns (Data storage data) {
        bytes32 slot = STORAGE_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            data.slot := slot
        }
    }

}
