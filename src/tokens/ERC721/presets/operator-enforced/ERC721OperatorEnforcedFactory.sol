// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {
    IERC721OperatorEnforcedFactory,
    IERC721OperatorEnforcedFactoryFunctions
} from "@0xsequence/contracts-library/tokens/ERC721/presets/operator-enforced/IERC721OperatorEnforcedFactory.sol";
import {ERC721OperatorEnforced} from
    "@0xsequence/contracts-library/tokens/ERC721/presets/operator-enforced/ERC721OperatorEnforced.sol";
import {SequenceProxyFactory} from "@0xsequence/contracts-library/proxies/SequenceProxyFactory.sol";

/**
 * Deployer of ERC-721 Operator Enforced proxies.
 */
contract ERC721OperatorEnforcedFactory is IERC721OperatorEnforcedFactory, SequenceProxyFactory {
    /**
     * Creates an ERC-721 Operator Enforced Factory.
     * @param factoryOwner The owner of the ERC-721 Operator Enforced Factory
     */
    constructor(address factoryOwner) {
        ERC721OperatorEnforced impl = new ERC721OperatorEnforced();
        SequenceProxyFactory._initialize(address(impl), factoryOwner);
    }

    /// @inheritdoc IERC721OperatorEnforcedFactoryFunctions
    function deploy(
        address proxyOwner,
        address tokenOwner,
        string memory name,
        string memory symbol,
        string memory baseURI,
        string memory contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        address operatorAllowlist
    ) external returns (address proxyAddr) {
        bytes32 salt = keccak256(
            abi.encode(
                tokenOwner, name, symbol, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator, operatorAllowlist
            )
        );
        proxyAddr = _createProxy(salt, proxyOwner, "");
        ERC721OperatorEnforced(proxyAddr).initialize(
            tokenOwner, name, symbol, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator, operatorAllowlist
        );
        emit ERC721OperatorEnforcedDeployed(proxyAddr);
        return proxyAddr;
    }

    /// @inheritdoc IERC721OperatorEnforcedFactoryFunctions
    function determineAddress(
        address proxyOwner,
        address tokenOwner,
        string memory name,
        string memory symbol,
        string memory baseURI,
        string memory contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        address operatorAllowlist
    ) external view returns (address proxyAddr) {
        bytes32 salt = keccak256(
            abi.encode(
                tokenOwner, name, symbol, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator, operatorAllowlist
            )
        );
        return _computeProxyAddress(salt, proxyOwner, "");
    }
}
