// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IMerkleProofSingleUse } from "./IMerkleProofSingleUse.sol";

import { MerkleProof } from "openzeppelin-contracts/contracts/utils/cryptography/MerkleProof.sol";

/**
 * Require single use merkle proofs per root.
 */
abstract contract MerkleProofSingleUse is IMerkleProofSingleUse {

    // Stores proofs used per root
    mapping(bytes32 => mapping(bytes32 => bool)) private _proofUsed;

    /**
     * Requires the given merkle proof to be valid.
     * @param root Merkle root.
     * @param proof Merkle proof.
     * @param addr Address to check.
     * @param salt Salt used to generate the merkle leaf.
     * @notice Fails when the proof is invalid or the proof has already been claimed by this address.
     * @dev This function reverts on failure.
     */
    function requireMerkleProof(bytes32 root, bytes32[] calldata proof, address addr, bytes32 salt) internal {
        if (root != bytes32(0)) {
            bytes32 leaf = _getLeaf(addr, salt);
            if (!_checkMerkleProof(root, proof, leaf)) {
                revert MerkleProofInvalid(root, proof, addr, salt);
            }
            _proofUsed[root][leaf] = true;
        }
    }

    /**
     * Checks if the given merkle proof is valid.
     * @param root Merkle root.
     * @param proof Merkle proof.
     * @param addr Address to check.
     * @param salt Salt used to generate the merkle leaf.
     * @return True if the proof is valid and has not yet been used by {addr}.
     */
    function checkMerkleProof(
        bytes32 root,
        bytes32[] calldata proof,
        address addr,
        bytes32 salt
    ) public view returns (bool) {
        return _checkMerkleProof(root, proof, _getLeaf(addr, salt));
    }

    function _getLeaf(address addr, bytes32 salt) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(addr, salt));
    }

    function _checkMerkleProof(bytes32 root, bytes32[] calldata proof, bytes32 leaf) internal view returns (bool) {
        return !_proofUsed[root][leaf] && MerkleProof.verify(proof, root, leaf);
    }

}
