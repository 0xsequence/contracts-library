// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/**
 * @dev Library for reading and writing primitive types to specific storage slots.
 *
 * Storage slots are often used to avoid storage conflict when dealing with upgradeable contracts.
 * This library helps with reading and writing to such slots without the need for inline assembly.
 *
 * The functions in this library return Slot structs that contain a `value` member that can be used to read or write.
 */
library StorageSlot {

    struct AddressSlot {
        address value;
    }

    struct BooleanSlot {
        bool value;
    }

    struct Bytes32Slot {
        bytes32 value;
    }

    struct Uint256Slot {
        uint256 value;
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function _getAddressSlot(
        bytes32 _slot
    ) internal pure returns (AddressSlot storage r) {
        assembly {
            // solhint-disable-line no-inline-assembly
            r.slot := _slot
        }
    }

    /**
     * @dev Returns an `BooleanSlot` with member `value` located at `slot`.
     */
    function _getBooleanSlot(
        bytes32 _slot
    ) internal pure returns (BooleanSlot storage r) {
        assembly {
            // solhint-disable-line no-inline-assembly
            r.slot := _slot
        }
    }

    /**
     * @dev Returns an `Bytes32Slot` with member `value` located at `slot`.
     */
    function _getBytes32Slot(
        bytes32 _slot
    ) internal pure returns (Bytes32Slot storage r) {
        assembly {
            // solhint-disable-line no-inline-assembly
            r.slot := _slot
        }
    }

    /**
     * @dev Returns an `Uint256Slot` with member `value` located at `slot`.
     */
    function _getUint256Slot(
        bytes32 _slot
    ) internal pure returns (Uint256Slot storage r) {
        assembly {
            // solhint-disable-line no-inline-assembly
            r.slot := _slot
        }
    }

}
