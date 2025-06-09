// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { SequenceProxyFactory } from "../../../../proxies/SequenceProxyFactory.sol";
import { ERC1155Sale } from "./ERC1155Sale.sol";
import { IERC1155SaleFactory, IERC1155SaleFactoryFunctions } from "./IERC1155SaleFactory.sol";

/**
 * Deployer of ERC-1155 Sale proxies.
 */
contract ERC1155SaleFactory is IERC1155SaleFactory, SequenceProxyFactory {

    /**
     * Creates an ERC-1155 Sale Factory.
     * @param factoryOwner The owner of the ERC-1155 Sale Factory
     */
    constructor(
        address factoryOwner
    ) {
        ERC1155Sale impl = new ERC1155Sale();
        SequenceProxyFactory._initialize(address(impl), factoryOwner);
    }

    /// @inheritdoc IERC1155SaleFactoryFunctions
    function deploy(
        address proxyOwner,
        address tokenOwner,
        address items,
        address implicitModeValidator,
        bytes32 implicitModeProjectId
    ) external returns (address proxyAddr) {
        bytes32 salt = keccak256(abi.encode(tokenOwner, items, implicitModeValidator, implicitModeProjectId));
        proxyAddr = _createProxy(salt, proxyOwner, "");
        ERC1155Sale(proxyAddr).initialize(tokenOwner, items, implicitModeValidator, implicitModeProjectId);
        emit ERC1155SaleDeployed(proxyAddr);
        return proxyAddr;
    }

    /// @inheritdoc IERC1155SaleFactoryFunctions
    function determineAddress(
        address proxyOwner,
        address tokenOwner,
        address items,
        address implicitModeValidator,
        bytes32 implicitModeProjectId
    ) external view returns (address proxyAddr) {
        bytes32 salt = keccak256(abi.encode(tokenOwner, items, implicitModeValidator, implicitModeProjectId));
        return _computeProxyAddress(salt, proxyOwner, "");
    }

}
