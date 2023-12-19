# ERC20 Contracts

This subsection contains contracts related to the [ERC20 token standard](https://eips.ethereum.org/EIPS/eip-20).

## ERC20BaseToken

This contract is a base implementation of the ERC-20 token standard. It includes role based access control features from the [OpenZeppelin AccessControlEnumberable](https://docs.openzeppelin.com/contracts/4.x/access-control) contract, to provide control over added features. Please refer to OpenZeppelin documentation for more information on `AccessControlEnumberable`.

## Presets

This folder contains contracts that are pre-configured for specific use cases.

### Items

The `ERC20Items` contract is a preset that configures the `ERC20BaseToken` contract to allow minting of tokens. It adds a `MINTER_ROLE` and a `mint(address to, uint256 amount)` function that can only be called by accounts with the `MINTER_ROLE`.

## Usage

This section of this repo utilitizes a factory pattern that deploys proxies contracts. This allows for a single deployment of each `Factory` contract, and subsequent deployments of the contracts with minimal gas costs.

1. Deploy the `[XXX]Factory` contract for the contract you wish to use (or use an existing deployment).
2. Call the `deploy` function on the factory, providing the desired parameters.
3. A new contract will be created and initialized, ready for use.

## Dependencies

These contract relies on the OpenZeppelin Contracts library, particularly the `ERC20`, `IERC20`, `IERC20Metadata`, and `AccessControlEnumberable` contracts, which provide core ERC-20 functionality and secure access control mechanisms.

## Access Controls

The contracts use the `AccessControlEnumberable` contract from OpenZeppelin to provide role based access control.
Role keys are defined as the `keccak256` value of the role name.
The following roles are defined:

| Role                 | Description        | Key                                                                  |
| -------------------- | ------------------ | -------------------------------------------------------------------- |
| `DEFAULT_ADMIN_ROLE` | Can updates roles. | `0x0`                                                                |
| `MINTER_ROLE`        | Can mint tokens.   | `0x9f2df0fed2c77648de5860a4cc508cd0818c85b8b8a1ab4ceeef8d981c8956a6` |
