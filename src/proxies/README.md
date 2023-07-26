# Proxies

This subsection of the repository contains the implementation of proxy contracts. 
These proxies delegate calls to an implementation contract, which allows the logic of the contract to be upgraded without changing the address of the contract.

## Features

### Transparent Upgradeable Beacon Proxy

This proxy follows the [Transparent Upgradeable Proxy](https://docs.openzeppelin.com/contracts/4.x/api/proxy#TransparentUpgradeableProxy) pattern from OpenZeppelin, unless the implementation is unset, then it uses the [Beacon Proxy](https://docs.openzeppelin.com/contracts/4.x/api/proxy#BeaconProxy) pattern.

This allows multiple proxies to be upgraded simultaneously, while also allowing individual upgrades to contracts.

### Sequence Proxy Factory

A factory for deploying Transparent Upgradeable Beacon Proxies.

## Usage

To use the contracts in this section, import the Sequence Proxy Factory contract and use the call the internal functions. For example:

```solidity
import {SequenceProxyFactory} from "./proxies/SequenceProxyFactory.sol";

contract MyContractFactory is SequenceProxyFactory {

    constructor(address factoryOwner) {
        MyImplementation impl = new MyImplementation();
        SequenceProxyFactory._initialize(address(impl), factoryOwner);
    }
    
    function deploy(address proxyOwner, bytes32 salt) external returns (address) {
        return _createProxy(salt, proxyOwner, "");
    }
}
```
