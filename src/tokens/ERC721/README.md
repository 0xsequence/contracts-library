# ERC721 Contracts

This subsection contains contracts related to the [ERC721 token standard](https://eips.ethereum.org/EIPS/eip-721).

## ERC721Token

This contract is a complete, ready-to-use implementation of the ERC-721 token standard. It leverages the [Azuki ERC-721A implementation](https://www.erc721a.org/) for gas efficiency. It includes role based access control features from the [OpenZeppelin AccessControl](https://docs.openzeppelin.com/contracts/4.x/access-control) contract, providing control over minting operations and metadata administration. Please refer to OpenZeppelin documentation for more information on AccessControl.

The ERC721Token contract has a two-step deployment process. First, it's deployed with an empty constructor. After deployment, the `initialize` function must be called to set the owner, token name, symbol, and base URI. This process is in place to support proxy deployments with the ERC721TokenFactory.

The contract supports the [ERC2981 token royalty standard](https://eips.ethereum.org/EIPS/eip-2981) via the ERC2981Controlled contract. Please refer to the ERC2981Controlled documentation for more information on token royalty.

### Functions

* `initialize(address owner, string memory tokenName_, string memory tokenSymbol_, string memory baseURI_)`: Initializes the token contract, setting the owner, name, symbol, and base URI.
* `mint(address to, uint256 amount)`: Mints the given amount of tokens to the specified address. This function is restricted to addresses with the Minter role.
* `setBaseMetadataURI(string memory baseURI_)`: Updates the base URI for the token metadata. This function is restricted to addresses with the Metadata Admin role.

## ERC721TokenFactory

This contract deploys ERC721Token contracts. It uses a proxy pattern to create new token instances to reduce gas costs.

The deployment uses a `salt` which is combined with the caller's address for cross chain consistency and security.

### Functions

* `deploy(address owner, string memory name, string memory symbol, string memory baseURI, bytes32 salt)`: Deploys a new ERC721Token proxy contract, initializes it, and emits an ERC721TokenDeployed event.

## Usage

To create a new ERC721 token:

1. Deploy the ERC721TokenFactory contract (or use an existing deployment).
2. Call the `deploy` function on the factory, providing the desired parameters.
3. A new ERC721Token contract will be created and initialized, ready for use.

## Dependencies

This repo relies on the ERC721A, IERC721A, ERC721AQueryable, and IERC721AQueryable contracts from Azuki for core ERC-721 functionality, AccessControl from OpenZeppelin for role base permissions and the ERC2981Controlled contract for handling of royalties.
