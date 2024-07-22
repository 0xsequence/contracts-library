// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC1271Wallet} from "@0xsequence/erc-1155/contracts/interfaces/IERC1271Wallet.sol";

contract ERC1271Mock is IERC1271Wallet {
    mapping(bytes32 => bool) private _validSignatures;

    function setValidSignature(bytes32 signature) public {
        _validSignatures[signature] = true;
    }

    function isValidSignature(bytes calldata, bytes calldata signature)
        external
        view
        override
        returns (bytes4 magicValue)
    {
        bytes32 sigBytes32 = abi.decode(signature, (bytes32));
        if (_validSignatures[sigBytes32]) {
            return 0x20c13b0b;
        } else {
            return 0x0;
        }
    }

    function isValidSignature(bytes32, bytes calldata signature) external view override returns (bytes4 magicValue) {
        bytes32 sigBytes32 = abi.decode(signature, (bytes32));
        if (_validSignatures[sigBytes32]) {
            return 0x1626ba7e;
        } else {
            return 0x0;
        }
    }
}
