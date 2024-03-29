// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ERC1155Items} from "@0xsequence/contracts-library/tokens/ERC1155/presets/items/ERC1155Items.sol";
import {IERC1155ItemsFactory} from
    "@0xsequence/contracts-library/tokens/ERC1155/presets/items/IERC1155ItemsFactory.sol";
import {SequenceProxyFactory} from "@0xsequence/contracts-library/proxies/SequenceProxyFactory.sol";

/**
 * Deployer of ERC-1155 Items proxies.
 */
contract ERC1155ItemsFactory is IERC1155ItemsFactory, SequenceProxyFactory {
    /**
     * Creates an ERC-1155 Items Factory.
     * @param factoryOwner The owner of the ERC-1155 Items Factory
     */
    constructor(address factoryOwner) {
        ERC1155Items impl = new ERC1155Items();
        SequenceProxyFactory._initialize(address(impl), factoryOwner);
    }

    /**
     * Creates an ERC-1155 Items proxy.
     * @param proxyOwner The owner of the ERC-1155 Items proxy
     * @param tokenOwner The owner of the ERC-1155 Items implementation
     * @param name The name of the ERC-1155 Items proxy
     * @param baseURI The base URI of the ERC-1155 Items proxy
     * @param contractURI The contract URI of the ERC-1155 Items proxy
     * @param royaltyReceiver Address of who should be sent the royalty payment
     * @param royaltyFeeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @return proxyAddr The address of the ERC-1155 Items Proxy
     */
    function deploy(
        address proxyOwner,
        address tokenOwner,
        string memory name,
        string memory baseURI,
        string memory contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    )
        external
        returns (address proxyAddr)
    {
        bytes32 salt = keccak256(abi.encode(tokenOwner, name, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator));
        proxyAddr = _createProxy(salt, proxyOwner, "");
        ERC1155Items(proxyAddr).initialize(tokenOwner, name, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator);
        emit ERC1155ItemsDeployed(proxyAddr);
        return proxyAddr;
    }
}
