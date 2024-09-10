// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC721SoulboundFactory, IERC721SoulboundFactoryFunctions} from
    "@0xsequence/contracts-library/tokens/ERC721/presets/soulbound/IERC721SoulboundFactory.sol";
import {ERC721Soulbound} from "@0xsequence/contracts-library/tokens/ERC721/presets/soulbound/ERC721Soulbound.sol";
import {SequenceProxyFactory} from "@0xsequence/contracts-library/proxies/SequenceProxyFactory.sol";

/**
 * Deployer of ERC-721 Soulbound proxies.
 */
contract ERC721SoulboundFactory is IERC721SoulboundFactory, SequenceProxyFactory {
    /**
     * Creates an ERC-721 Soulbound Factory.
     * @param factoryOwner The owner of the ERC-721 Soulbound Factory
     */
    constructor(address factoryOwner) {
        ERC721Soulbound impl = new ERC721Soulbound();
        SequenceProxyFactory._initialize(address(impl), factoryOwner);
    }

    /// @inheritdoc IERC721SoulboundFactoryFunctions
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
        ERC721Soulbound(proxyAddr).initialize(tokenOwner, name, symbol, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator);
        emit ERC721SoulboundDeployed(proxyAddr);
        return proxyAddr;
    }

    /// @inheritdoc IERC721SoulboundFactoryFunctions
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
