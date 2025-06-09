// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { SequenceProxyFactory } from "../../../../proxies/SequenceProxyFactory.sol";
import { ERC20Items } from "./ERC20Items.sol";
import { IERC20ItemsFactory, IERC20ItemsFactoryFunctions } from "./IERC20ItemsFactory.sol";

/**
 * Deployer of ERC-20 Items proxies.
 */
contract ERC20ItemsFactory is IERC20ItemsFactory, SequenceProxyFactory {

    /**
     * Creates an ERC-20 Items Factory.
     * @param factoryOwner The owner of the ERC-20 Items Factory
     */
    constructor(
        address factoryOwner
    ) {
        ERC20Items impl = new ERC20Items();
        SequenceProxyFactory._initialize(address(impl), factoryOwner);
    }

    /// @inheritdoc IERC20ItemsFactoryFunctions
    function deploy(
        address proxyOwner,
        address tokenOwner,
        string memory name,
        string memory symbol,
        uint8 decimals,
        address implicitModeValidator,
        bytes32 implicitModeProjectId
    ) external returns (address proxyAddr) {
        bytes32 salt =
            keccak256(abi.encode(tokenOwner, name, symbol, decimals, implicitModeValidator, implicitModeProjectId));
        proxyAddr = _createProxy(salt, proxyOwner, "");
        ERC20Items(proxyAddr).initialize(
            tokenOwner, name, symbol, decimals, implicitModeValidator, implicitModeProjectId
        );
        emit ERC20ItemsDeployed(proxyAddr);
        return proxyAddr;
    }

    /// @inheritdoc IERC20ItemsFactoryFunctions
    function determineAddress(
        address proxyOwner,
        address tokenOwner,
        string memory name,
        string memory symbol,
        uint8 decimals,
        address implicitModeValidator,
        bytes32 implicitModeProjectId
    ) external view returns (address proxyAddr) {
        bytes32 salt =
            keccak256(abi.encode(tokenOwner, name, symbol, decimals, implicitModeValidator, implicitModeProjectId));
        return _computeProxyAddress(salt, proxyOwner, "");
    }

}
