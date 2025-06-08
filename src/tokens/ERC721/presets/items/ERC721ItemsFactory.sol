// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { SequenceProxyFactory } from "../../../../proxies/SequenceProxyFactory.sol";
import { ERC721Items } from "./ERC721Items.sol";
import { IERC721ItemsFactory, IERC721ItemsFactoryFunctions } from "./IERC721ItemsFactory.sol";

/**
 * Deployer of ERC-721 Items proxies.
 */
contract ERC721ItemsFactory is IERC721ItemsFactory, SequenceProxyFactory {

    /**
     * Creates an ERC-721 Items Factory.
     * @param factoryOwner The owner of the ERC-721 Items Factory
     */
    constructor(
        address factoryOwner
    ) {
        ERC721Items impl = new ERC721Items();
        SequenceProxyFactory._initialize(address(impl), factoryOwner);
    }

    /// @inheritdoc IERC721ItemsFactoryFunctions
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
        ERC721Items(proxyAddr).initialize(
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
        emit ERC721ItemsDeployed(proxyAddr);
        return proxyAddr;
    }

    /// @inheritdoc IERC721ItemsFactoryFunctions
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
