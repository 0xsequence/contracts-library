# ERC721 Contracts

This subsection contains contracts related to the [ERC721 token standard](https://eips.ethereum.org/EIPS/eip-721).

## ERC721BaseToken

This contract is a base implementation of the ERC-721 token standard. It leverages the [Azuki ERC-721A implementation](https://www.erc721a.org/) for gas efficiency. It includes role based access control features from the [OpenZeppelin AccessControlEnumberable](https://docs.openzeppelin.com/contracts/4.x/access-control) contract, to provide control over added features. Please refer to OpenZeppelin documentation for more information on `AccessControlEnumberable`.

The contract supports the [ERC2981 token royalty standard](https://eips.ethereum.org/EIPS/eip-2981) via the ERC2981Controlled contract. Please refer to the ERC2981Controlled documentation for more information on token royalty.

## Presets

This folder contains contracts that are pre-configured for specific use cases.

### Items

The `ERC721Items` contract is a preset that configures the `ERC721BaseToken` contract to allow minting of tokens. It adds a `MINTER_ROLE` and a `mint(address to, uint256 amount)` function that can only be called by accounts with the `MINTER_ROLE`.

### Operator Enforced

The `ERC721OperatorEnforced` contract is a preset that configures the `ERC721BaseToken` contract to allow for operator enforced transfers and approvals. It adds an `operatorAllowlist` parameter to the constructor that must point to an `OperatorAllowlist` contract.

For more information on Operator Allowlist Enforcement, please refer to the [Immutable Operator Allowlist Specification](https://docs.immutable.com/products/zkevm/minting/royalties/allowlist-spec) documentation.

### Sale

The `ERC721Sale` contract is a preset that configures the `ERC721BaseToken` contract to allow for the sale of tokens. It adds a `mint(address to, uint256 amount, bytes32[] memory proof)` function allows for the minting of tokens under various conditions.

Conditions may be set by the contract owner using the `setSaleDetails(uint256 supplyCap, uint256 cost, address paymentToken, uint64 startTime, uint64 endTime, bytes32 merkleRoot)` function that can only be called by accounts with the `MINT_ADMIN_ROLE`. The variables function as follows:

- supplyCap: The maximum number of tokens that can be minted. 0 indicates unlimited supply.
- cost: The amount of payment tokens to accept for each token minted.
- paymentToken: The ERC20 token address to accept payment in. address(0) indicates ETH.
- startTime: The start time of the sale. Tokens cannot be minted before this time.
- endTime: The end time of the sale. Tokens cannot be minted after this time.
- merkleRoot: The merkle root for allowlist minting.

When using a merkle proof, each caller may only use each root once. To prevent collisions ensure the same root is not used for multiple sale details.
Leaves are defined as `keccak256(abi.encodePacked(caller, uint256(0))`. The `caller` is the message sender, who will also receive the tokens.

## Usage

This section of this repo utilitizes a factory pattern that deploys proxies contracts. This allows for a single deployment of each `Factory` contract, and subsequent deployments of the contracts with minimal gas costs.

1. Deploy the `[XXX]Factory` contract for the contract you wish to use (or use an existing deployment).
2. Call the `deploy` function on the factory, providing the desired parameters.
3. A new contract will be created and initialized, ready for use.

## Dependencies

This repo relies on the `ERC721A`, `IERC721A`, `ERC721AQueryable`, and `IERC721AQueryable` contracts from Azuki for core ERC-721 functionality, `AccessControlEnumberable` from OpenZeppelin for role base permissions and the ERC2981Controlled contract for handling of royalties.

## Access Controls

The contracts use the `AccessControlEnumberable` contract from OpenZeppelin to provide role based access control.
Role keys are defined as the `keccak256` value of the role name.
The following roles are defined:

| Role                  | Description                        | Key                                                                  |
| --------------------- | ---------------------------------- | -------------------------------------------------------------------- |
| `DEFAULT_ADMIN_ROLE`  | Can updates roles.                 | `0x0`                                                                |
| `METADATA_ADMIN_ROLE` | Can update metadata.               | `0xe02a0315b383857ac496e9d2b2546a699afaeb4e5e83a1fdef64376d0b74e5a5` |
| `MINTER_ROLE`         | Can mint tokens.                   | `0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6` |
| `MINT_ADMIN_ROLE`     | Can set minting logic.             | `0x4c02318d8c3aadc98ccf18aebbf3126f651e0c3f6a1de5ff8edcf6724a2ad5c2` |
| `WITHDRAW_ROLE`       | Withdraw tokens from the contract. | `0x5d8e12c39142ff96d79d04d15d1ba1269e4fe57bb9d26f43523628b34ba108ec` |
