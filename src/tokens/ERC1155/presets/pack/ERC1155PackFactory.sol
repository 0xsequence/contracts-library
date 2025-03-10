// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ERC1155Pack} from "@0xsequence/contracts-library/tokens/ERC1155/presets/pack/ERC1155Pack.sol";
import {
    IERC1155PackFactory,
    IERC1155PackFactoryFunctions
} from "@0xsequence/contracts-library/tokens/ERC1155/presets/pack/IERC1155PackFactory.sol";
import {SequenceProxyFactory} from "@0xsequence/contracts-library/proxies/SequenceProxyFactory.sol";

/**
 * Deployer of ERC-1155 Pack proxies.
 */
contract ERC1155PackFactory is IERC1155PackFactory, SequenceProxyFactory {
    /**
     * Creates an ERC-1155 Pack Factory.
     * @param factoryOwner The owner of the ERC-1155 Pack Factory
     */
    constructor(address factoryOwner) {
        ERC1155Pack impl = new ERC1155Pack();
        SequenceProxyFactory._initialize(address(impl), factoryOwner);
    }

    /// @inheritdoc IERC1155PackFactoryFunctions
    function deploy(
        address proxyOwner,
        address tokenOwner,
        string memory name,
        string memory baseURI,
        string memory contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        bytes32 merkleRoot,
        uint256 supply
    ) external returns (address proxyAddr) {
        bytes32 salt =
            keccak256(abi.encode(tokenOwner, name, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator));
        proxyAddr = _createProxy(salt, proxyOwner, "");
        ERC1155Pack(proxyAddr).initialize(
            tokenOwner, name, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator, merkleRoot, supply
        );
        emit ERC1155PackDeployed(proxyAddr);
        return proxyAddr;
    }

    /// @inheritdoc IERC1155PackFactoryFunctions
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
