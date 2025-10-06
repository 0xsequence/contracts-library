// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { SequenceProxyFactory } from "../../../../proxies/SequenceProxyFactory.sol";
import { ERC1155Pack } from "./ERC1155Pack.sol";
import { IERC1155PackFactory, IERC1155PackFactoryFunctions } from "./IERC1155PackFactory.sol";

/**
 * Deployer of ERC-1155 Pack proxies.
 */
contract ERC1155PackFactory is IERC1155PackFactory, SequenceProxyFactory {

    /**
     * Creates an ERC-1155 Pack Factory.
     * @param factoryOwner The owner of the ERC-1155 Pack Factory
     * @param holderFallback The address of the ERC1155Holder fallback
     */
    constructor(address factoryOwner, address holderFallback) {
        ERC1155Pack impl = new ERC1155Pack(holderFallback);
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
        address implicitModeValidator,
        bytes32 implicitModeProjectId
    ) external override returns (address proxyAddr) {
        bytes32 salt = keccak256(
            abi.encode(
                tokenOwner,
                name,
                baseURI,
                contractURI,
                royaltyReceiver,
                royaltyFeeNumerator,
                implicitModeValidator,
                implicitModeProjectId
            )
        );
        proxyAddr = _createProxy(salt, proxyOwner, "");
        ERC1155Pack(proxyAddr).initialize(
            tokenOwner,
            name,
            baseURI,
            contractURI,
            royaltyReceiver,
            royaltyFeeNumerator,
            implicitModeValidator,
            implicitModeProjectId
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
        uint96 royaltyFeeNumerator,
        address implicitModeValidator,
        bytes32 implicitModeProjectId
    ) external view override returns (address proxyAddr) {
        bytes32 salt = keccak256(
            abi.encode(
                tokenOwner,
                name,
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
