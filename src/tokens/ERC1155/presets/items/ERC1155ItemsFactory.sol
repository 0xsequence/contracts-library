// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { SequenceProxyFactory } from "../../../../proxies/SequenceProxyFactory.sol";
import { ERC1155Items } from "./ERC1155Items.sol";
import { IERC1155ItemsFactory, IERC1155ItemsFactoryFunctions } from "./IERC1155ItemsFactory.sol";

/**
 * Deployer of ERC-1155 Items proxies.
 */
contract ERC1155ItemsFactory is IERC1155ItemsFactory, SequenceProxyFactory {

    /**
     * Creates an ERC-1155 Items Factory.
     * @param factoryOwner The owner of the ERC-1155 Items Factory
     */
    constructor(
        address factoryOwner
    ) {
        ERC1155Items impl = new ERC1155Items();
        SequenceProxyFactory._initialize(address(impl), factoryOwner);
    }

    /// @inheritdoc IERC1155ItemsFactoryFunctions
    function deploy(
        address proxyOwner,
        address tokenOwner,
        string memory name,
        string memory baseURI,
        string memory contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) external returns (address proxyAddr) {
        bytes32 salt =
            keccak256(abi.encode(tokenOwner, name, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator));
        proxyAddr = _createProxy(salt, proxyOwner, "");
        ERC1155Items(proxyAddr).initialize(tokenOwner, name, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator);
        emit ERC1155ItemsDeployed(proxyAddr);
        return proxyAddr;
    }

    /// @inheritdoc IERC1155ItemsFactoryFunctions
    function determineAddress(
        address proxyOwner,
        address tokenOwner,
        string memory name,
        string memory baseURI,
        string memory contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) external view returns (address proxyAddr) {
        bytes32 salt =
            keccak256(abi.encode(tokenOwner, name, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator));
        return _computeProxyAddress(salt, proxyOwner, "");
    }

}
