// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// @title ERC721MintAccessControlStorage
/// @author Michael Standen
/// @notice Storage for the ERC721 mint access control module.
library ERC721MintAccessControlStorage {

    /// @notice ERC721MintAccessControl storage struct
    /// @param nextSequentialId The next sequential id to mint
    /// @custom:storage-location erc7201:erc721MintAccessControl.data
    struct Data {
        uint256 nextSequentialId;
    }

    bytes32 private constant STORAGE_SLOT =
        keccak256(abi.encode(uint256(keccak256("erc721MintAccessControl.data")) - 1)) & ~bytes32(uint256(0xff));

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
