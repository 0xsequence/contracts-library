# ERC1155 Contracts

This subsection contains contracts related to the [ERC1155 token standard](https://eips.ethereum.org/EIPS/eip-1155).

## ERC1155Token

This contract is a complete, ready-to-use implementation of the ERC-1155 token standard. It includes additional features from the ERC1155MintBurn, ERC1155Meta, and ERC1155Metadata contracts. These contracts provide minting capabilities, support for meta transactions, and metadata functionality.

Meta transactions are provided by the [0xSequence ERC1155 library](https://github.com/0xsequence/erc-1155/blob/master/SPECIFICATIONS.md#meta-transactions). Please refer to library documentation for more information on meta transactions.

The ERC1155Token contract has a two-step deployment process. First, it's deployed with an empty constructor. After deployment, the `initialize` function must be called to set the owner, name, and base URI. This process is in place to support proxy deployments with the ERC1155TokenFactory.

### Functions

* `initialize(address owner, string memory name_, string memory baseURI_)`: Initializes the token contract, setting the owner, name, and base URI.
* `mint(address to, uint256 tokenId, uint256 amount, bytes memory data)`: Mints the specified amount of tokens of a given ID to the specified address. This function is restricted to addresses with the Minter role.
* `batchMint(address to, uint256[] memory tokenIds, uint256[] memory amounts, bytes memory data)`: Mints specified amounts of tokens of given IDs to the specified address. This function is restricted to addresses with the Minter role.
* `setBaseMetadataURI(string memory baseURI_)`: Updates the base URI for the token metadata. This function is restricted to addresses with the Metadata Admin role.
* `setContractName(string memory name_)`: Updates the contract's name. This function is restricted to addresses with the Metadata Admin role.

## ERC1155TokenFactory

This contract deploys ERC1155Token contracts. It uses a proxy pattern to create new token instances to reduce gas costs.

The deployment uses a `salt` which is combined with the caller's address for cross chain consistency and security.

### Functions

* `deploy(address owner, string memory name, string memory baseURI, bytes32 salt)`: Deploys a new ERC1155Token proxy contract, initializes it, and emits an ERC1155TokenDeployed event.

## Usage

To create a new ERC1155 token:

1. Deploy the ERC1155TokenFactory contract (or use an existing deployment).
2. Call the `deploy` function on the factory, providing the desired parameters.
3. A new ERC1155Token contract will be created and initialized, ready for use.

## Dependencies

This repository relies on the ERC1155, ERC1155MintBurn, ERC1155Meta, ERC1155Metadata contracts from 0xSequence for core ERC-1155 functionality, AccessControl from OpenZeppelin for role base permissions and the ERC2981Controlled contract for handling of royalties.
