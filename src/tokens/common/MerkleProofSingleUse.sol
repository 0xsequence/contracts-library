// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IMerkleProofSingleUse} from "@0xsequence/contracts-library/tokens/common/IMerkleProofSingleUse.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

/**
 * Require single use merkle proofs per address.
 */
abstract contract MerkleProofSingleUse is IMerkleProofSingleUse {

    // Stores proofs used by an address
    mapping(address => mapping(bytes32 => bool)) private _proofUsed;

    /**
     * Requires the given merkle proof to be valid.
     * @param root Merkle root.
     * @param proof Merkle proof.
     * @param addr Address to check.
     * @notice Fails when the proof is invalid or the proof has already been claimed by this address.
     * @dev This function reverts on failure.
     */
    function requireMerkleProof(bytes32 root, bytes32[] calldata proof, address addr) internal {
        if (root != bytes32(0)) {
            if (!checkMerkleProof(root, proof, addr)) {
                revert MerkleProofInvalid(root, proof, addr);
            }
            _proofUsed[addr][root] = true;
        }
    }

    /**
     * Checks if the given merkle proof is valid.
     * @param root Merkle root.
     * @param proof Merkle proof.
     * @param addr Address to check.
     * @return True if the proof is valid and has not yet been used by {addr}.
     */
    function checkMerkleProof(bytes32 root, bytes32[] calldata proof, address addr) public view returns (bool) {
        return !_proofUsed[addr][root] && MerkleProof.verify(proof, root, keccak256(abi.encodePacked(addr)));
    }

}
