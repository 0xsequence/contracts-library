// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { SequenceProxyFactory } from "../../../../proxies/SequenceProxyFactory.sol";
import { ERC721Sale } from "./ERC721Sale.sol";
import { IERC721SaleFactory, IERC721SaleFactoryFunctions } from "./IERC721SaleFactory.sol";

/**
 * Deployer of ERC-721 Sale proxies.
 */
contract ERC721SaleFactory is IERC721SaleFactory, SequenceProxyFactory {

    /**
     * Creates an ERC-721 Sale Factory.
     * @param factoryOwner The owner of the ERC-721 Sale Factory
     */
    constructor(
        address factoryOwner
    ) {
        ERC721Sale impl = new ERC721Sale();
        SequenceProxyFactory._initialize(address(impl), factoryOwner);
    }

    /// @inheritdoc IERC721SaleFactoryFunctions
    function deploy(
        uint256 nonce,
        address proxyOwner,
        address tokenOwner,
        address items,
        address implicitModeValidator,
        bytes32 implicitModeProjectId
    ) external returns (address proxyAddr) {
        bytes32 salt = keccak256(abi.encode(nonce, tokenOwner, items, implicitModeValidator, implicitModeProjectId));
        proxyAddr = _createProxy(salt, proxyOwner, "");
        ERC721Sale(proxyAddr).initialize(tokenOwner, items, implicitModeValidator, implicitModeProjectId);
        emit ERC721SaleDeployed(proxyAddr);
        return proxyAddr;
    }

    /// @inheritdoc IERC721SaleFactoryFunctions
    function determineAddress(
        uint256 nonce,
        address proxyOwner,
        address tokenOwner,
        address items,
        address implicitModeValidator,
        bytes32 implicitModeProjectId
    ) external view returns (address proxyAddr) {
        bytes32 salt = keccak256(abi.encode(nonce, tokenOwner, items, implicitModeValidator, implicitModeProjectId));
        return _computeProxyAddress(salt, proxyOwner, "");
    }

}
