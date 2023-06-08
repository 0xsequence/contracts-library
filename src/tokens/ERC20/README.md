# ERC20 Contracts

This subsection contains contracts related to the [ERC20 token standard](https://eips.ethereum.org/EIPS/eip-20).

## ERC20Token

This contract is a complete, ready-to-use implementation of the ERC-20 token standard. It includes role based access control features from the [OpenZeppelin AccessControl](https://docs.openzeppelin.com/contracts/4.x/access-control) contract, providing control over minting operations. Please refer to OpenZeppelin documentation for more information on AccessControl.

The ERC20Token contract has a two-step deployment process. First, it's deployed with an empty constructor. After deployment, the `initialize` function must be called to set the owner, token name, symbol, and decimals. This process is in place to support proxy deployments with the ERC20TokenFactory.

### Functions

* `initialize(address owner, string memory tokenName_, string memory tokenSymbol_, uint8 tokenDecimals_)`: Initializes the token contract, setting the owner, name, symbol, and number of decimals.
* `mint(address to, uint256 amount)`: Mints the given amount of tokens toP the specified address. This function is restricted to addresses with the Minter role.

## ERC20TokenFactory

This contract deploys ERC20Token contracts. It uses a proxy pattern to create new token instances to reduce gas costs.

The deployment uses a `salt` which is combined with the caller's address for cross chain consistency and security.

### Functions

* `deploy(address owner, string memory name, string memory symbol, uint8 decimals, bytes32 salt)`: Deploys a new ERC20Token proxy contract, initializes it, and emits an ERC20TokenDeployed event.

## Usage

To create a new ERC20 token:

1. Deploy the ERC20TokenFactory contract (or use an existing deployment).
2. Call the `deploy` function on the factory, providing the desired parameters.
3. A new ERC20Token contract will be created and initialized, ready for use.

## Dependencies

This repo relies on the OpenZeppelin Contracts library, particularly the ERC20, IERC20, IERC20Metadata, and AccessControl contracts, which provide core ERC-20 functionality and secure access control mechanisms.
