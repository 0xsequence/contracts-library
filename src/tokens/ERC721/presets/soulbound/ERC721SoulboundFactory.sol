// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { SequenceProxyFactory } from "../../../../proxies/SequenceProxyFactory.sol";
import { ERC721Soulbound } from "./ERC721Soulbound.sol";
import { IERC721SoulboundFactory, IERC721SoulboundFactoryFunctions } from "./IERC721SoulboundFactory.sol";

/**
 * Deployer of ERC-721 Soulbound proxies.
 */
contract ERC721SoulboundFactory is IERC721SoulboundFactory, SequenceProxyFactory {

    /**
     * Creates an ERC-721 Soulbound Factory.
     * @param factoryOwner The owner of the ERC-721 Soulbound Factory
     */
    constructor(
        address factoryOwner
    ) {
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
        uint96 royaltyFeeNumerator,
        address implicitModeValidator,
        bytes32 implicitModeProjectId
    ) external returns (address proxyAddr) {
        bytes32 salt = keccak256(
            abi.encode(
                tokenOwner,
                name,
                symbol,
                baseURI,
                contractURI,
                royaltyReceiver,
                royaltyFeeNumerator,
                implicitModeValidator,
                implicitModeProjectId
            )
        );
        proxyAddr = _createProxy(salt, proxyOwner, "");
        ERC721Soulbound(proxyAddr).initialize(
            tokenOwner,
            name,
            symbol,
            baseURI,
            contractURI,
            royaltyReceiver,
            royaltyFeeNumerator,
            implicitModeValidator,
            implicitModeProjectId
        );
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
        uint96 royaltyFeeNumerator,
        address implicitModeValidator,
        bytes32 implicitModeProjectId
    ) external view returns (address proxyAddr) {
        bytes32 salt = keccak256(
            abi.encode(
                tokenOwner,
                name,
                symbol,
                baseURI,
                contractURI,
                royaltyReceiver,
                royaltyFeeNumerator,
                implicitModeValidator,
                implicitModeProjectId
            )
        );
        return _computeProxyAddress(salt, proxyOwner, "");
    }

}
