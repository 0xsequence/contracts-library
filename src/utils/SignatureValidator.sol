// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ECDSA} from "solady/utils/ECDSA.sol";
import {IERC1271Wallet} from "@0xsequence/erc-1155/contracts/interfaces/IERC1271Wallet.sol";

library SignatureValidator {
    using ECDSA for bytes32;

    uint8 private constant SIG_TYPE_ERC712 = 1;
    uint8 private constant SIG_TYPE_ERC1271 = 2;

    bytes4 internal constant ERC1271_MAGICVALUE = 0x1626ba7e;

    /**
     * Check if a signature is valid.
     * @param digest The digest to check.
     * @param signature The signature to check.
     * @return signer The detected signer address if valid, otherwise address(0).
     * @dev An ERC721 signature is formatted `0x01<signature>`.
     * @dev An ERC1271 signature is formatted `0x02<signer><signature>`.
     */
    function recoverSigner(bytes32 digest, bytes calldata signature) internal view returns (address signer) {
        // Check first byte of signature for signature type
        uint8 sigType = uint8(signature[0]);
        if (sigType == SIG_TYPE_ERC712) {
            // ERC712
            signer = digest.recoverCalldata(signature[1:]);
        } else if (sigType == SIG_TYPE_ERC1271 && signature.length >= 21) {
            // ERC1271
            assembly {
                let word := calldataload(add(1, signature.offset))
                signer := shr(96, word)
            }
            try IERC1271Wallet(signer).isValidSignature(digest, signature[21:]) returns (bytes4 magicValue) {
                if (magicValue != ERC1271_MAGICVALUE) {
                    signer = address(0);
                }
            } catch {
                signer = address(0);
            }
        }
    }
}
