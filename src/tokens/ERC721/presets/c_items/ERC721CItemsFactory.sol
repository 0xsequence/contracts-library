// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC721CItemsFactory, IERC721CItemsFactoryFunctions} from
    "@0xsequence/contracts-library/tokens/ERC721/presets/c_items/IERC721CItemsFactory.sol";
import {ERC721CItems} from "@0xsequence/contracts-library/tokens/ERC721/presets/c_items/ERC721CItems.sol";
import {SequenceProxyFactory} from "@0xsequence/contracts-library/proxies/SequenceProxyFactory.sol";

/**
 * Deployer of ERC-721C Items proxies.
 */
contract ERC721CItemsFactory is IERC721CItemsFactory, SequenceProxyFactory {
    /**
     * Creates an ERC-721C Items Factory.
     * @param factoryOwner The owner of the ERC-721C Items Factory
     */
    constructor(address factoryOwner) {
        ERC721CItems impl = new ERC721CItems();
        SequenceProxyFactory._initialize(address(impl), factoryOwner);
    }

    /// @inheritdoc IERC721CItemsFactoryFunctions
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
        ERC721CItems(proxyAddr).initialize(tokenOwner, name, symbol, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator);
        emit ERC721CItemsDeployed(proxyAddr);
        return proxyAddr;
    }

    /// @inheritdoc IERC721CItemsFactoryFunctions
    function determineAddress(
        address proxyOwner,
        address tokenOwner,
        string memory name,
        string memory symbol,
        string memory baseURI,
        string memory contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) external view returns (address proxyAddr)
    {
        bytes32 salt =
            keccak256(abi.encode(tokenOwner, name, symbol, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator));
        return _computeProxyAddress(salt, proxyOwner, "");
    }
}
