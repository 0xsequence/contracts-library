// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// @title SignalsImplicitModeStorage
/// @author Michael Standen
/// @notice Storage for the implicit mode module.
library SignalsImplicitModeStorage {

    /// @notice SignalsImplicitMode storage struct
    /// @param validator The validator address
    /// @param projectId The project id
    /// @custom:storage-location erc7201:signalsimplicitmode.data
    struct Data {
        address validator;
        bytes32 projectId;
    }

    bytes32 private constant STORAGE_SLOT =
        keccak256(abi.encode(uint256(keccak256("signalsimplicitmode.data")) - 1)) & ~bytes32(uint256(0xff));

    /// @notice Get the implicit mode storage from storage
    /// @return data The stored implicit mode data
    function load() internal pure returns (Data storage data) {
        bytes32 slot = STORAGE_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            data.slot := slot
        }
    }

}
