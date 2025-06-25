# ERC1155 Contracts

This subsection contains contracts related to the [ERC1155 token standard](https://eips.ethereum.org/EIPS/eip-1155).

## ERC1155BaseToken

This contract is a base implementation of the ERC-1155 token standard. It includes role based access control features from the [OpenZeppelin AccessControlEnumberable](https://docs.openzeppelin.com/contracts/4.x/access-control) contract, to provide control over added features. Please refer to OpenZeppelin documentation for more information on `AccessControlEnumberable`.

This contracts provide minting capabilities, support for meta transactions, and metadata functionality. It includes additional features from the ERC1155MintBurn and ERC1155Metadata contracts. Please refer to library documentation for more information on meta transactions.

The contract supports the [ERC2981 token royalty standard](https://eips.ethereum.org/EIPS/eip-2981) via the ERC2981Controlled contract. Please refer to the ERC2981Controlled documentation for more information on token royalty.

## Presets

This folder contains contracts that are pre-configured for specific use cases.

### Items

The `ERC1155Items` contract is a preset that configures the `ERC1155BaseToken` contract to allow minting of tokens. It adds a `MINTER_ROLE` and a `mint(address to, uint256 amount)` function that can only be called by accounts with the `MINTER_ROLE`.

### Sale

The `ERC1155Sale` contract is a preset that configures the `ERC1155BaseToken` contract to allow for the sale of tokens. It adds a `mint(address to, , uint256[] memory tokenIds, uint256[] memory amounts, bytes memory data, bytes32[] calldata proof)` function allows for the minting of tokens under various conditions.

Conditions may be set by the contract owner. Set the payment token with `setPaymentToken(address paymentTokenAddr)`, then use either the `setTokenSaleDetails(uint256 tokenId, uint256 cost, uint256 remainingSupply, uint64 startTime, uint64 endTime, bytes32 merkleRoot)` function for single token settings or the `setGlobalSaleDetails(uint256 cost, uint256 remainingSupply, uint64 startTime, uint64 endTime, bytes32 merkleRoot)` function for global settings. These functions can only be called by accounts with the `MINT_ADMIN_ROLE`.

When using a merkle proof, each caller may only use each root once. To prevent collisions ensure the same root is not used for multiple sale details.
Leaves are defined as `keccak256(abi.encodePacked(caller, tokenId))`. The `caller` is the message sender, who will also receive the tokens. The `tokenId` is the id of the token that will be minted, (for global sales `type(uint256).max` is used).

For information about the function parameters, please refer to the function specification in `presets/sale/IERC1155Sale.sol`.

## Usage

This section of this repo utilitizes a factory pattern that deploys proxies contracts. This allows for a single deployment of each `Factory` contract, and subsequent deployments of the contracts with minimal gas costs.

1. Deploy the `[XXX]Factory` contract for the contract you wish to use (or use an existing deployment).
2. Call the `deploy` function on the factory, providing the desired parameters.
3. A new contract will be created and initialized, ready for use.

## Dependencies

This repository relies on the ERC1155, ERC1155MintBurn, ERC1155Metadata contracts from 0xSequence for core ERC-1155 functionality, `AccessControlEnumberable` from OpenZeppelin for role base permissions and the ERC2981Controlled contract for handling of royalties.

## Access Controls

The contracts use the `AccessControlEnumberable` contract from OpenZeppelin to provide role based access control.
Role keys are defined as the `keccak256` value of the role name.
The following roles are defined:

| Role                       | Description                                   | Key                                                                  |
| -------------------------- | --------------------------------------------- | -------------------------------------------------------------------- |
| `DEFAULT_ADMIN_ROLE`       | Can updates roles.                            | `0x0`                                                                |
| `METADATA_ADMIN_ROLE`      | Can update metadata.                          | `0xe02a0315b383857ac496e9d2b2546a699afaeb4e5e83a1fdef64376d0b74e5a5` |
| `MINTER_ROLE`              | Can mint tokens.                              | `0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6` |
| `MINT_ADMIN_ROLE`          | Can set minting logic.                        | `0x4c02318d8c3aadc98ccf18aebbf3126f651e0c3f6a1de5ff8edcf6724a2ad5c2` |
| `WITHDRAW_ROLE`            | Withdraw tokens from the contract.            | `0x5d8e12c39142ff96d79d04d15d1ba1269e4fe57bb9d26f43523628b34ba108ec` |
| `IMPLICIT_MODE_ADMIN_ROLE` | Update settings for implicit mode validation. | `0x70649ec320b507febad3e8ef750e5f580b9ae32f9f50d4c7b121332c81971530` |
