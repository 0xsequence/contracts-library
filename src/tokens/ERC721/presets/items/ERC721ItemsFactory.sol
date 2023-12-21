// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC721ItemsFactory} from
    "@0xsequence/contracts-library/tokens/ERC721/presets/items/IERC721ItemsFactory.sol";
import {ERC721Items} from "@0xsequence/contracts-library/tokens/ERC721/presets/items/ERC721Items.sol";
import {SequenceProxyFactory} from "@0xsequence/contracts-library/proxies/SequenceProxyFactory.sol";

/**
 * Deployer of ERC-721 Items proxies.
 */
contract ERC721ItemsFactory is IERC721ItemsFactory, SequenceProxyFactory {
    /**
     * Creates an ERC-721 Items Factory.
     * @param factoryOwner The owner of the ERC-721 Items Factory
     */
    constructor(address factoryOwner) {
        ERC721Items impl = new ERC721Items();
        SequenceProxyFactory._initialize(address(impl), factoryOwner);
    }

    /**
     * Creates an ERC-721 Items proxy.
     * @param proxyOwner The owner of the ERC-721 Items proxy
     * @param tokenOwner The owner of the ERC-721 Items implementation
     * @param name The name of the ERC-721 Items proxy
     * @param symbol The symbol of the ERC-721 Items proxy
     * @param baseURI The base URI of the ERC-721 Items proxy
     * @param contractURI The contract URI of the ERC-721 Items proxy
     * @param royaltyReceiver Address of who should be sent the royalty payment
     * @param royaltyFeeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @return proxyAddr The address of the ERC-721 Items Proxy
     */
    function deploy(
        address proxyOwner,
        address tokenOwner,
        string memory name,
        string memory symbol,
        string memory baseURI,
        string memory contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    )
        external
        returns (address proxyAddr)
    {
        bytes32 salt =
            keccak256(abi.encode(tokenOwner, name, symbol, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator));
        proxyAddr = _createProxy(salt, proxyOwner, "");
        ERC721Items(proxyAddr).initialize(tokenOwner, name, symbol, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator);
        emit ERC721ItemsDeployed(proxyAddr);
        return proxyAddr;
    }
}
