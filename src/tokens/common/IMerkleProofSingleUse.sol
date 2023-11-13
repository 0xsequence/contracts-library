// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IMerkleProofSingleUseFunctions {

    /**
     * Checks if the given merkle proof is valid.
     * @param root Merkle root.
     * @param proof Merkle proof.
     * @param addr Address to check.
     * @return True if the proof is valid and has not yet been used by {addr}.
     */
    function checkMerkleProof(bytes32 root, bytes32[] calldata proof, address addr) external view returns (bool);
}

interface IMerkleProofSingleUseSignals {

    /**
     * Thrown when the merkle proof is invalid or has already been used.
     * @param root Merkle root.
     * @param proof Merkle proof.
     * @param addr Address to check.
     */
    error MerkleProofInvalid(bytes32 root, bytes32[] proof, address addr);

}

interface IMerkleProofSingleUse is IMerkleProofSingleUseFunctions, IMerkleProofSingleUseSignals {}
