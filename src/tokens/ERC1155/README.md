# ERC1155 Contracts

This subsection contains contracts related to the [ERC1155 token standard](https://eips.ethereum.org/EIPS/eip-1155).

## ERC1155Token

This contract is a base implementation of the ERC-1155 token standard. It includes role based access control features from the [OpenZeppelin AccessControl](https://docs.openzeppelin.com/contracts/4.x/access-control) contract, to provide control over added features. Please refer to OpenZeppelin documentation for more information on AccessControl.

This contracts provide minting capabilities, support for meta transactions, and metadata functionality. It includes additional features from the ERC1155MintBurn, ERC1155Meta, and ERC1155Metadata contracts. Meta transactions are provided by the [0xSequence ERC1155 library](https://github.com/0xsequence/erc-1155/blob/master/SPECIFICATIONS.md#meta-transactions). Please refer to library documentation for more information on meta transactions.

The contract supports the [ERC2981 token royalty standard](https://eips.ethereum.org/EIPS/eip-2981) via the ERC2981Controlled contract. Please refer to the ERC2981Controlled documentation for more information on token royalty.

## Presets

This folder contains contracts that are pre-configured for specific use cases.

### Minter

The `ERC1155TokenMinter` contract is a preset that configures the `ERC1155Token` contract to allow minting of tokens. It adds a `MINTER_ROLE` and a `mint(address to, uint256 amount)` function that can only be called by accounts with the `MINTER_ROLE`.

### Sale

The `ERC1155TokenSale` contract is a preset that configures the `ERC1155Token` contract to allow for the sale of tokens. It adds a `mint(address to, , uint256[] memory tokenIds, uint256[] memory amounts, bytes memory data, bytes32[] calldata proof)` function allows for the minting of tokens under various conditions.

Conditions may be set by the contract owner using either the `setTokenSaleDetails(uint256 tokenId, uint256 cost, uint256 supplyCap, uint64 startTime, uint64 endTime, bytes32 merkleRoot)` function for single token settings or the `setGlobalSaleDetails(uint256 cost, uint256 supplyCap, address paymentTokenAddr, uint64 startTime, uint64 endTime, bytes32 merkleRoot)` function for global settings. These functions can only be called by accounts with the `MINT_ADMIN_ROLE`. 

For information about the function parameters, please refer to the function specification in `presets/sale/IERC1155Sale.sol`.

## Usage

This section of this repo utilitizes a factory pattern that deploys proxies contracts. This allows for a single deployment of each `Factory` contract, and subsequent deployments of the contracts with minimal gas costs.

1. Deploy the `[XXX]Factory` contract for the contract you wish to use (or use an existing deployment).
2. Call the `deploy` function on the factory, providing the desired parameters.
3. A new contract will be created and initialized, ready for use.

## Dependencies

This repository relies on the ERC1155, ERC1155MintBurn, ERC1155Meta, ERC1155Metadata contracts from 0xSequence for core ERC-1155 functionality, AccessControl from OpenZeppelin for role base permissions and the ERC2981Controlled contract for handling of royalties.
