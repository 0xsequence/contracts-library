// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// @title ERC2981Storage
/// @author Michael Standen
/// @notice Storage for the ERC2981 module.
library ERC2981Storage {

    /// @notice Royalty info struct
    /// @param receiver The address to pay the royalty to
    /// @param royaltyBps The royalty fraction in basis points
    struct RoyaltyInfo {
        address receiver;
        uint96 royaltyBps;
    }

    /// @notice ERC2981 storage struct
    /// @param defaultRoyalty The default royalty
    /// @param tokenRoyalty The royalty for each token
    /// @custom:storage-location erc7201:erc2981.data
    struct Data {
        RoyaltyInfo defaultRoyalty;
        mapping(uint256 => RoyaltyInfo) tokenRoyalty;
    }

    bytes32 private constant STORAGE_SLOT =
        keccak256(abi.encode(uint256(keccak256("erc2981.data")) - 1)) & ~bytes32(uint256(0xff));

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
