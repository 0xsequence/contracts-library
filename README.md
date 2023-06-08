# Sequence Contracts Library

This repository provides a set of smart contracts to facilitate the creation and management of contracts deployable on EVM compatible chains, including ERC20, ERC721, and ERC1155 token standards. These contracts are designed for gas efficiency and reuse via proxy deployments.

## Features

* **ERC20TokenFactory**: Allows for the easy creation of new ERC20 tokens through a factory contract and also provides functionality for minting new tokens.

* **ERC721TokenFactory**: Similar to the ERC20TokenFactory, but for ERC721 (non-fungible) tokens. It allows for the creation and minting of ERC721 tokens, and also supports ERC2981 royalty information.

* **ERC1155TokenFactory**: A factory for creating ERC1155 tokens, which can represent semi-fungible items. This contract also supports minting and updating metadata, as well as ERC2981 royalty information.

* **Common Token Functionality**: This contains contracts that can be used for additional functionalities, such as the `ERC2981Controlled` contract which provides a way to handle royalties in NFTs.

* **Proxies**: This section contains contracts implementing ERC1967 compliant proxies for upgradeability.

## Usage

1. Clone the repository
2. Install dependencies with `yarn`
3. Compile the contracts with `yarn build`
4. Run tests with `yarn test`

### Deployment

```sh
yarn deploy
```

**Note:** The Factory contracts in this repository contain no state and are not ownable, as such they only need to be deployed once per network. The Factory contracts are then available to be used by anyone.

## Dependencies

The contracts in this repository are built with Solidity ^0.8.17 and use OpenZeppelin and Azuki contracts for standards implementation and additional functionalities such as access control.

## License

All contracts in this repository are released under the Apache-2.0 license.
