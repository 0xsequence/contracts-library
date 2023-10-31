// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {ERC20TokenMinter} from "@0xsequence/contracts-library/tokens/ERC20/presets/minter/ERC20TokenMinter.sol";
import {IERC20TokenMinterFactory} from
    "@0xsequence/contracts-library/tokens/ERC20/presets/minter/IERC20TokenMinterFactory.sol";
import {SequenceProxyFactory} from "@0xsequence/contracts-library/proxies/SequenceProxyFactory.sol";

/**
 * Deployer of ERC-20 Token Minter proxies.
 */
contract ERC20TokenMinterFactory is IERC20TokenMinterFactory, SequenceProxyFactory {
    /**
     * Creates an ERC-20 Token Minter Factory.
     * @param factoryOwner The owner of the ERC-20 Token Minter Factory
     */
    constructor(address factoryOwner) {
        ERC20TokenMinter impl = new ERC20TokenMinter();
        SequenceProxyFactory._initialize(address(impl), factoryOwner);
    }

    /**
     * Creates an ERC-20 Token Minter proxy.
     * @param proxyOwner The owner of the ERC-20 Token Minter proxy
     * @param tokenOwner The owner of the ERC-20 Token Minter implementation
     * @param name The name of the ERC-20 Token Minter proxy
     * @param symbol The symbol of the ERC-20 Token Minter proxy
     * @param decimals The decimals of the ERC-20 Token Minter proxy
     * @return proxyAddr The address of the ERC-20 Token Minter Proxy
     * @dev As `proxyOwner` owns the proxy, it will be unable to call the ERC-20 Token Minter functions.
     */
    function deploy(address proxyOwner, address tokenOwner, string memory name, string memory symbol, uint8 decimals)
        external
        returns (address proxyAddr)
    {
        bytes32 salt = keccak256(abi.encodePacked(tokenOwner, name, symbol, decimals));
        proxyAddr = _createProxy(salt, proxyOwner, "");
        ERC20TokenMinter(proxyAddr).initialize(tokenOwner, name, symbol, decimals);
        emit ERC20TokenMinterDeployed(proxyAddr);
        return proxyAddr;
    }
}
