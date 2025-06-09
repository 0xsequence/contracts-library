// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { SequenceProxyFactory } from "../proxies/SequenceProxyFactory.sol";
import { IPaymentsFactory, IPaymentsFactoryFunctions } from "./IPaymentsFactory.sol";
import { Payments } from "./Payments.sol";

/**
 * Deployer of Payments proxies.
 */
contract PaymentsFactory is IPaymentsFactory, SequenceProxyFactory {

    /**
     * Creates an Payments Factory.
     * @param factoryOwner The owner of the Payments Factory
     */
    constructor(
        address factoryOwner
    ) {
        Payments impl = new Payments();
        SequenceProxyFactory._initialize(address(impl), factoryOwner);
    }

    /// @inheritdoc IPaymentsFactoryFunctions
    function deploy(
        address proxyOwner,
        address paymentsOwner,
        address paymentsSigner
    ) external returns (address proxyAddr) {
        bytes32 salt = keccak256(abi.encode(paymentsOwner, paymentsSigner));
        proxyAddr = _createProxy(salt, proxyOwner, "");
        Payments(proxyAddr).initialize(paymentsOwner, paymentsSigner);
        emit PaymentsDeployed(proxyAddr);
        return proxyAddr;
    }

    /// @inheritdoc IPaymentsFactoryFunctions
    function determineAddress(
        address proxyOwner,
        address paymentsOwner,
        address paymentsSigner
    ) external view returns (address proxyAddr) {
        bytes32 salt = keccak256(abi.encode(paymentsOwner, paymentsSigner));
        return _computeProxyAddress(salt, proxyOwner, "");
    }

}
