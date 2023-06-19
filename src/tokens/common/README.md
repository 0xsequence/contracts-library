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

Alternatively, use the `ERC721Token` or `ERC1155Token` implementations which already extend this contract.

### Dependencies

The `ERC2981Controlled` contract depends on OpenZeppelin's `ERC2981` and `AccessControl` contracts. `ERC2981` provides the basic royalty-related functionality according to the standard, while `AccessControl` provides a flexible system of access control based on roles.
