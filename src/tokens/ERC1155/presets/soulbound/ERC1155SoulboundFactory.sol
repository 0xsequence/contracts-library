// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ERC1155Soulbound} from "@0xsequence/contracts-library/tokens/ERC1155/presets/soulbound/ERC1155Soulbound.sol";
import {
    IERC1155SoulboundFactory,
    IERC1155SoulboundFactoryFunctions
} from "@0xsequence/contracts-library/tokens/ERC1155/presets/soulbound/IERC1155SoulboundFactory.sol";
import {SequenceProxyFactory} from "@0xsequence/contracts-library/proxies/SequenceProxyFactory.sol";

/**
 * Deployer of ERC-1155 Soulbound proxies.
 */
contract ERC1155SoulboundFactory is IERC1155SoulboundFactory, SequenceProxyFactory {
    /**
     * Creates an ERC-1155 Soulbound Factory.
     * @param factoryOwner The owner of the ERC-1155 Soulbound Factory
     */
    constructor(address factoryOwner) {
        ERC1155Soulbound impl = new ERC1155Soulbound();
        SequenceProxyFactory._initialize(address(impl), factoryOwner);
    }

    /// @inheritdoc IERC1155SoulboundFactoryFunctions
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
        ERC1155Soulbound(proxyAddr).initialize(
            tokenOwner, name, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator
        );
        emit ERC1155SoulboundDeployed(proxyAddr);
        return proxyAddr;
    }

    /// @inheritdoc IERC1155SoulboundFactoryFunctions
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
