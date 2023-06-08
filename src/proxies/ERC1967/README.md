# ERC1967 Proxies

This subsection of the repository contains the implementation of [ERC1967 proxy contracts](https://eips.ethereum.org/EIPS/eip-1967). ERC1967 defines a standard for storage slots of upgradeable smart contract proxies. These proxies delegate calls to an implementation contract, which allows the logic of the contract to be upgraded without changing the address of the contract.

## Features

* **IERC1967**: This interface defines the standard events emitted by ERC1967 proxies - `Upgraded`, `AdminChanged`, and `BeaconUpgraded`.

* **Proxy**: This is the core contract that acts as a ERC1967 proxy. It contains logic to forward calls to an implementation contract, allowing the contract to change its behavior over time without changing its address.

* **ProxyDeployer**: This contract provides a helper function for deploying new proxies. It contains the logic to compute the address of a proxy before it is deployed, as well as a function to check if an address is a contract.

**Note:** The current implementations do not support upgradeable proxies.

## Usage

To use the contracts in this section, import the desired contracts from the "proxies/ERC1967" directory and use the provided functions to deploy and interact with proxy contracts. For example:

```solidity
import {ProxyDeployer} from "./proxies/ERC1967/ProxyDeployer.sol";

contract MyContractFactory is ProxyDeployer {
    function deployNewContract(address implementation) public returns (address) {
        return _deployProxy(implementation, keccak256(abi.encode(msg.sender)));
    }
}
```
