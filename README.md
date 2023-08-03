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

1. Clone the repository
2. Install dependencies with `yarn`
3. Compile the contracts with `yarn build`
4. Run tests with `yarn test`

### Deployment

Copy `.env.example` to `.env` and set your wallet configuration.

```sh
cp .env.example .env
```

Then run the deployment script.

```sh
yarn deploy
```

**Note:** The Factory contracts in this repository contain no state and are not ownable, as such they only need to be deployed once per network. The Factory contracts are then available to be used by anyone.

## Dependencies

The contracts in this repository are built with Solidity ^0.8.17 and use 0xSequence, OpenZeppelin and Azuki contracts for standards implementation and additional functionalities such as access control.

## License

All contracts in this repository are released under the Apache-2.0 license.
