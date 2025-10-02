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

### Packs

The `ERC1155Pack` contract is a preset that extends `ERC1155Items` to provide a pack opening mechanism for ERC1155 tokens. It implements a commit-reveal scheme to ensure fair and verifiable pack opening.

Pack contents are managed by accounts with the `PACK_ADMIN_ROLE` using the `setPacksContent(bytes32 _merkleRoot, uint256 _supply, uint256 packId)` function. The merkle root contains all possible pack contents, and the supply determines how many packs can be opened.

#### Flow

The pack opening process works as follows:

1. User calls `commit(uint256 packId)` to burn their pack and create a commitment
2. After at least one block, anyone may call `reveal(address user, PackContent calldata packContent, bytes32[] calldata proof, uint256 packId)` with a merkle proof of the selected pack content
3. The contract verifies the proof and mints the revealed tokens to the user
4. As a safety feature, if reveal isn't called while the block hash is still available (before it expires), they can call `refundPack(address user, uint256 packId)` to get their pack back

> [!NOTE]
> By allowing the `reveal` function to be called from anyone, a third party can ensure every committed pack is revealed before the blockhash becomes unaccessible on chain.

#### Randomization Mechanism

The pack opening uses a commit-reveal scheme with block hash randomness to ensure fair and unpredictable selection:

1. **Commitment Phase**: When a user calls `commit(uint256 packId)`, the contract records the current block number plus one (`block.number + 1`) as the commitment block
2. **Random Seed Generation**: During reveal, the contract uses the block hash of the commitment block combined with the user's address to generate a random seed: `keccak256(abi.encode(blockHash, user))`
3. **Index Selection**: The random seed is used to select an index from the remaining available pack contents: `randomSeed % remainingSupply[packId]`
4. **Fisher-Yates Shuffle**: The contract maintains an `_availableIndices` mapping that implements a Fisher-Yates shuffle algorithm, ensuring each pack content can only be selected once and maintaining uniform distribution
5. **Verification**: The selected index corresponds to a specific pack content in the merkle tree. The merkle leaf is constructed as `keccak256(abi.encode(revealIdx, packContent))`, which must be provided as a proof during the reveal phase

> [!WARNING]
> This randomization technique is susceptible to attacks by entities that can control sequential blocks (such as large mining pools or validators). An attacker with significant hash power could potentially manipulate block hashes to influence the randomness outcome.

## Utilities

This folder contains contracts that work in conjunction with other ERC1155 contracts.

### Sale

The `ERC1155Sale` contract is a utility contract that provides sale functionality for ERC-1155 tokens. It works in conjunction with an `ERC1155Items` contract to handle the minting and sale of tokens under various conditions.

The contract supports multiple sale configurations through a sale details system. Each sale configuration includes:

- Token ID range (minTokenId to maxTokenId)
- Cost per token
- Payment token (ETH or ERC20)
- Supply limit per token ID
- Sale time window (startTime to endTime)
- Optional merkle root for allowlist minting

Conditions may be set by the contract owner using the `addSaleDetails(SaleDetails calldata details)` function for new configurations or `updateSaleDetails(uint256 saleIndex, SaleDetails calldata details)` for existing ones. These functions can only be called by accounts with the `MINT_ADMIN_ROLE`.

When using a merkle proof, each caller may only use each root once. To prevent collisions ensure the same root is not used for multiple sale details.
Leaves are defined as `keccak256(abi.encodePacked(caller, tokenId))`. The `caller` is the message sender, who will also receive the tokens. The `tokenId` is the id of the token that will be minted.

For information about the function parameters, please refer to the function specification in `utility/sale/IERC1155Sale.sol`.

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
| `PACK_ADMIN_ROLE`          | Can manage pack contents and settings.        | `0xbaa5ee745de68a3095827d2ee7dd2043afc932834d02cc1b8be3da78577f6c1a` |
