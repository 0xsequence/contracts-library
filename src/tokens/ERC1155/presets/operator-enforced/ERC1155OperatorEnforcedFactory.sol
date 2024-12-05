// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {
    IERC1155OperatorEnforcedFactory,
    IERC1155OperatorEnforcedFactoryFunctions
} from "@0xsequence/contracts-library/tokens/ERC1155/presets/operator-enforced/IERC1155OperatorEnforcedFactory.sol";
import {ERC1155OperatorEnforced} from
    "@0xsequence/contracts-library/tokens/ERC1155/presets/operator-enforced/ERC1155OperatorEnforced.sol";
import {SequenceProxyFactory} from "@0xsequence/contracts-library/proxies/SequenceProxyFactory.sol";

/**
 * Deployer of ERC-1155 Operator Enforced proxies.
 */
contract ERC1155OperatorEnforcedFactory is IERC1155OperatorEnforcedFactory, SequenceProxyFactory {
    /**
     * Creates an ERC-1155 Operator Enforced Factory.
     * @param factoryOwner The owner of the ERC-1155 Operator Enforced Factory
     */
    constructor(address factoryOwner) {
        ERC1155OperatorEnforced impl = new ERC1155OperatorEnforced();
        SequenceProxyFactory._initialize(address(impl), factoryOwner);
    }

    /// @inheritdoc IERC1155OperatorEnforcedFactoryFunctions
    function deploy(
        address proxyOwner,
        address tokenOwner,
        string memory tokenName,
        string memory tokenBaseURI,
        string memory tokenContractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        address operatorAllowlist
    ) external returns (address proxyAddr) {
        bytes32 salt = keccak256(
            abi.encode(
                tokenOwner,
                tokenName,
                tokenBaseURI,
                tokenContractURI,
                royaltyReceiver,
                royaltyFeeNumerator,
                operatorAllowlist
            )
        );
        proxyAddr = _createProxy(salt, proxyOwner, "");
        ERC1155OperatorEnforced(proxyAddr).initialize(
            tokenOwner,
            tokenName,
            tokenBaseURI,
            tokenContractURI,
            royaltyReceiver,
            royaltyFeeNumerator,
            operatorAllowlist
        );
        emit ERC1155OperatorEnforcedDeployed(proxyAddr);
        return proxyAddr;
    }

    /// @inheritdoc IERC1155OperatorEnforcedFactoryFunctions
    function determineAddress(
        address proxyOwner,
        address tokenOwner,
        string memory tokenName,
        string memory tokenBaseURI,
        string memory tokenContractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        address operatorAllowlist
    ) external view returns (address proxyAddr) {
        bytes32 salt = keccak256(
            abi.encode(
                tokenOwner,
                tokenName,
                tokenBaseURI,
                tokenContractURI,
                royaltyReceiver,
                royaltyFeeNumerator,
                operatorAllowlist
            )
        );
        return _computeProxyAddress(salt, proxyOwner, "");
    }
}
