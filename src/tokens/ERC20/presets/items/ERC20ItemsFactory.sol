// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ERC20Items} from "@0xsequence/contracts-library/tokens/ERC20/presets/items/ERC20Items.sol";
import {
    IERC20ItemsFactory,
    IERC20ItemsFactoryFunctions
} from "@0xsequence/contracts-library/tokens/ERC20/presets/items/IERC20ItemsFactory.sol";
import {SequenceProxyFactory} from "@0xsequence/contracts-library/proxies/SequenceProxyFactory.sol";

/**
 * Deployer of ERC-20 Items proxies.
 */
contract ERC20ItemsFactory is IERC20ItemsFactory, SequenceProxyFactory {
    /**
     * Creates an ERC-20 Items Factory.
     * @param factoryOwner The owner of the ERC-20 Items Factory
     */
    constructor(address factoryOwner) {
        ERC20Items impl = new ERC20Items();
        SequenceProxyFactory._initialize(address(impl), factoryOwner);
    }

    /// @inheritdoc IERC20ItemsFactoryFunctions
    function deploy(address proxyOwner, address tokenOwner, string memory name, string memory symbol, uint8 decimals)
        external
        returns (address proxyAddr)
    {
        bytes32 salt = keccak256(abi.encode(tokenOwner, name, symbol, decimals));
        proxyAddr = _createProxy(salt, proxyOwner, "");
        ERC20Items(proxyAddr).initialize(tokenOwner, name, symbol, decimals);
        emit ERC20ItemsDeployed(proxyAddr);
        return proxyAddr;
    }

    /// @inheritdoc IERC20ItemsFactoryFunctions
    function determineAddress(
        address proxyOwner,
        address tokenOwner,
        string memory name,
        string memory symbol,
        uint8 decimals
    ) external view returns (address proxyAddr) {
        bytes32 salt = keccak256(abi.encode(tokenOwner, name, symbol, decimals));
        return _computeProxyAddress(salt, proxyOwner, "");
    }
}
