// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ERC1155Lootbox} from "@0xsequence/contracts-library/tokens/ERC1155/presets/lootbox/ERC1155Lootbox.sol";
import {
    IERC1155LootboxFactory,
    IERC1155LootboxFactoryFunctions
} from "@0xsequence/contracts-library/tokens/ERC1155/presets/lootbox/IERC1155LootboxFactory.sol";
import {SequenceProxyFactory} from "@0xsequence/contracts-library/proxies/SequenceProxyFactory.sol";

/**
 * Deployer of ERC-1155 Lootbox proxies.
 */
contract ERC1155LootboxFactory is IERC1155LootboxFactory, SequenceProxyFactory {
    /**
     * Creates an ERC-1155 Lootbox Factory.
     * @param factoryOwner The owner of the ERC-1155 Lootbox Factory
     */
    constructor(address factoryOwner) {
        ERC1155Lootbox impl = new ERC1155Lootbox();
        SequenceProxyFactory._initialize(address(impl), factoryOwner);
    }

    /// @inheritdoc IERC1155LootboxFactoryFunctions
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
        ERC1155Lootbox(proxyAddr).initialize(
            tokenOwner, name, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator
        );
        emit ERC1155LootboxDeployed(proxyAddr);
        return proxyAddr;
    }

    /// @inheritdoc IERC1155LootboxFactoryFunctions
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
