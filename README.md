# Sequence Contracts Library

This repository provides a set of smart contracts to facilitate the creation and management of contracts deployable on EVM compatible chains, including ERC20, ERC721, and ERC1155 token standards. These contracts are designed for gas efficiency and reuse via proxy deployments.

## Features

Base and preset **implementations of common token standards**:

* ERC-20
* ERC-721
* ERC-1155

**Common token functionality**, such as the `ERC2981-Controlled` contract which provides a way to handle royalties in NFTs.

**Proxy** contracts and factories implementing ERC-1967 and with upgradeability.

## Usage

### Installation

Clone the repository, including git submodules.

Install dependencies with `yarn`.

Compile the contracts with `yarn build`.

### Testing

Run tests with `yarn test`.

Run coverage report with `yarn coverage`. View coverage report with `genhtml -o report --branch-coverage --ignore-errors category lcov.info && py -m http.server`. Viewing the report with this command requires Python to be installed.

Compare gas usage with `yarn snapshot:compare`. Note as some test use random values, the gas usage may vary slightly between runs.

### Deployment

Copy `.env.example` to `.env` and set your wallet configuration.

```sh
cp .env.example .env
```

Then run the deployment script.

```sh
yarn deploy
```

## Dependencies

The contracts in this repository are built with Solidity ^0.8.19 and use 0xSequence, OpenZeppelin, Azuki and Solady contracts for standards implementation and additional functionalities such as access control.

## Audits

The contracts in this repository have been audited by [Quantstamp](https://quantstamp.com). Audit reports are available in the [audits](./audits) folder.

## License

All contracts in this repository are released under the Apache-2.0 license.
