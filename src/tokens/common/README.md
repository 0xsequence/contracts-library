# Common Token Functionality

This section contains common contracts that can be used for additional functionality beyond the base token standards.

## ERC2981Controlled

The `ERC2981Controlled` contract is an implementation of the [ERC2981 token royalty standard](https://eips.ethereum.org/EIPS/eip-2981), which provides a standardized way to handle royalties in NFTs and SFTs.

This contract allows the royalty information for the contract as a whole, or individual token IDs, to be updated by users with the `ROYALTY_ADMIN_ROLE`.

### Functions

* `setDefaultRoyalty(address receiver, uint96 feeNumerator)`: Sets the default royalty information for all token IDs in the contract. The `receiver` is the address that will receive royalty payments, and the `feeNumerator` is the royalty fee expressed in basis points (e.g., 15% would be 1500). This function is restricted to users with the `ROYALTY_ADMIN_ROLE`.
* `setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator)`: Sets the royalty information for a specific token ID, overriding the default royalty information for that token ID. The parameters are the same as in `setDefaultRoyalty`. This function is restricted to users with the `ROYALTY_ADMIN_ROLE`.

### Usage

To use this contract, it should be inherited by the main token contract. For example:

```solidity
contract MyNFT is ERC721, ERC2981Controlled {
    // ...
}
```

After that, the royalty information can be set and updated by users with the `ROYALTY_ADMIN_ROLE`.

Alternatively, use the `ERC721BaseToken` or `ERC1155BaseToken` implementations which already extend this contract.

### Dependencies

The `ERC2981Controlled` contract depends on OpenZeppelin's `ERC2981` and `AccessControlEnumberable` contracts. `ERC2981` provides the basic royalty-related functionality according to the standard, while `AccessControlEnumberable` provides a flexible system of access control based on roles.

## MerkleProofSingleUse

The `MerkleProofSingleUse` contract provides a way to verify that a given value is included in a Merkle tree, and that it has not been used before.
This is useful for verifying that a given token ID has not been used before, for example in a claim process.

### Functions

* `checkMerkleProof(bytes32 root, bytes32[] calldata proof, address addr, bytes32 salt)`: An internal function that allows a contract to verify that a given value is included in a Merkle tree. The `root` is the Merkle root, the `proof` is the Merkle proof, and the `addr` is the value to verify. If the value is not included in the Merkle tree or if the proof has already been used, the function will return false.
* `requireMerkleProof(bytes32 root, bytes32[] calldata proof, address addr, bytes32 salt)`: An internal function that does the same as above, and also marks the proof has having been used by the address.

### Usage

To use this contract, it should be inherited by the main token contract and functions called as required. For example when minting in an NFT contract:

```solidity
contract MyNFT is ERC721, MerkleProofSingleUse {
    
    function mint(address to, bytes32 root, bytes32[] calldata proof) public {
        requireMerkleProof(root, proof, to, "");
        _mint(to, tokenId);
    }

    //...
}
```

### Dependencies

The `MerkleProofSingleUse` contract depends on OpenZeppelin's `MerkleProof` contract. `MerkleProof` provides the basic Merkle proof verification functionality.

## SignalsImplicitModeControlled

The `SignalsImplicitModeControlled` contract provides functionality for managing implicit session access for a given project. It integrates with the Sequence's implicit mode validation system.

### Functions

- `_initializeImplicitMode(address owner, address validator, bytes32 projectId)`: Internal function to initialize the implicit mode settings. Sets up the initial admin role and initializes the Signals implicit mode with the given validator and project ID.
- `setImplicitModeValidator(address validator)`: Allows an address with the `IMPLICIT_MODE_ADMIN_ROLE` to update the validator address for implicit mode validation.
- `setImplicitModeProjectId(bytes32 projectId)`: Allows an address with the `IMPLICIT_MODE_ADMIN_ROLE` to update the project ID for implicit mode validation.

### Usage

To use this contract, it should be inherited by the main token contract. For example:

```solidity
contract MyNFT is ERC721, SignalsImplicitModeControlled {
    constructor(address validator, bytes32 projectId) {
        _initializeImplicitMode(msg.sender, validator, projectId);
    }
    // ...
}
```

### Dependencies

The `SignalsImplicitModeControlled` contract depends on:

- OpenZeppelin's `AccessControlEnumerable` contract for role-based access control
- The Sequence's `SignalsImplicitMode` contract for implicit mode validation functionality

## WithdrawControlled

The `WithdrawControlled` contract provides a way to withdraw ETH and ERC20 tokens from a contract. This is useful for contracts that receive ETH or ERC20 tokens, and need to be able to withdraw them.

### Functions

* `withdrawETH(address payable to, uint256 value)`: Allows an address with the `WITHDRAW_ROLE` to withdraw ETH from the contract. The `to` parameter is the address to withdraw to, and the `value` is the amount to withdraw.
* `withdrawERC20(address token, address to, uint256 value)`: Allows an address with the `WITHDRAW_ROLE` to withdraw ERC20 tokens from the contract. The `token` parameter is the address of the ERC20 token to withdraw, the `to` parameter is the address to withdraw to, and the `value` is the amount to withdraw.

### Usage

To use this contract, it should be inherited by the main token contract. For example:

```solidity
contract MyNFT is ERC721, WithdrawControlled {
    // ...
}
```

### Dependencies

The `WithdrawControlled` contract depends on OpenZeppelin's `AccessControlEnumberable` contract. `AccessControlEnumberable` provides a flexible system of access control based on roles.
