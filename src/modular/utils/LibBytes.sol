// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.18;

/// @title Library for reading data from bytes arrays
/// @author Agustin Aguilar (aa@horizon.io), Michael Standen (mstan@horizon.io)
/// @notice This library contains functions for reading data from bytes arrays.
/// @dev These functions do not check if the input index is within the bounds of the data array.
/// @dev Reading out of bounds may return dirty values.
library LibBytes {

    function readBool(bytes calldata _data, uint256 _index) internal pure returns (bool a, uint256 newPointer) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let word := calldataload(add(_index, _data.offset))
            a := shr(248, word)
            newPointer := add(_index, 1)
        }
    }

    function readUint8(bytes calldata _data, uint256 _index) internal pure returns (uint8 a, uint256 newPointer) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let word := calldataload(add(_index, _data.offset))
            a := shr(248, word)
            newPointer := add(_index, 1)
        }
    }

    function readUint16(bytes calldata _data, uint256 _index) internal pure returns (uint16 a, uint256 newPointer) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let word := calldataload(add(_index, _data.offset))
            a := shr(240, word)
            newPointer := add(_index, 2)
        }
    }

    function readUint24(bytes calldata _data, uint256 _index) internal pure returns (uint24 a, uint256 newPointer) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let word := calldataload(add(_index, _data.offset))
            a := shr(232, word)
            newPointer := add(_index, 3)
        }
    }

    function readUint64(bytes calldata _data, uint256 _index) internal pure returns (uint64 a, uint256 newPointer) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let word := calldataload(add(_index, _data.offset))
            a := shr(192, word)
            newPointer := add(_index, 8)
        }
    }

    function readUint96(bytes calldata _data, uint256 _index) internal pure returns (uint96 a, uint256 newPointer) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let word := calldataload(add(_index, _data.offset))
            a := shr(160, word)
            newPointer := add(_index, 8)
        }
    }

    function readUint160(bytes calldata _data, uint256 _index) internal pure returns (uint160 a, uint256 newPointer) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let word := calldataload(add(_index, _data.offset))
            a := shr(96, word)
            newPointer := add(_index, 20)
        }
    }

    function readUint256(bytes calldata _data, uint256 _index) internal pure returns (uint256 a, uint256 newPointer) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            a := calldataload(add(_index, _data.offset))
            newPointer := add(_index, 32)
        }
    }

    function readUintX(
        bytes calldata _data,
        uint256 _index,
        uint256 _length
    ) internal pure returns (uint256 a, uint256 newPointer) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let word := calldataload(add(_index, _data.offset))
            let shift := sub(256, mul(_length, 8))
            a := and(shr(shift, word), sub(shl(mul(8, _length), 1), 1))
            newPointer := add(_index, _length)
        }
    }

    function readBytes4(bytes calldata _data, uint256 _pointer) internal pure returns (bytes4 a, uint256 newPointer) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let word := calldataload(add(_pointer, _data.offset))
            a := and(word, 0xffffffff00000000000000000000000000000000000000000000000000000000)
            newPointer := add(_pointer, 4)
        }
    }

    function readBytes32(
        bytes calldata _data,
        uint256 _pointer
    ) internal pure returns (bytes32 a, uint256 newPointer) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            a := calldataload(add(_pointer, _data.offset))
            newPointer := add(_pointer, 32)
        }
    }

    function readAddress(bytes calldata _data, uint256 _index) internal pure returns (address a, uint256 newPointer) {
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let word := calldataload(add(_index, _data.offset))
            a := and(shr(96, word), 0xffffffffffffffffffffffffffffffffffffffff)
            newPointer := add(_index, 20)
        }
    }

}
