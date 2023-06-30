// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

error MerkleProofInvalid(bytes32 root, bytes32[] proof, address account);

/**
 * Require single use merkle proofs per account.
 */
abstract contract MerkleProofSingleUse {

    // Stores proofs used by an account
    mapping(address => mapping(bytes32 => bool)) private _proofUsed;

    /**
     * Requires the given merkle proof to be valid.
     * @param root Merkle root.
     * @param proof Merkle proof.
     * @param account Account to check.
     * @notice Fails when the proof is invalid or the proof has already been claimed by this account.
     * @dev This function reverts on failure.
     */
    function requireMerkleProof(bytes32 root, bytes32[] calldata proof, address account) internal {
        if (root != bytes32(0)) {
            if (_proofUsed[account][root] || !checkMerkleProof(root, proof, account)) {
                revert MerkleProofInvalid(root, proof, account);
            }
            _proofUsed[account][root] = true;
        }
    }

    /**
     * Checks if the given merkle proof is valid.
     * @param root Merkle root.
     * @param proof Merkle proof.
     * @param account Account to check.
     * @return True if the proof is valid.
     */
    function checkMerkleProof(bytes32 root, bytes32[] calldata proof, address account) public pure returns (bool) {
        return MerkleProof.verify(proof, root, keccak256(abi.encodePacked(account)));
    }

}
