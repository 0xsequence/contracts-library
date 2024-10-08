// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IPaymentsFactoryFunctions {
    /**
     * Creates a Payments proxy contract
     * @param proxyOwner The owner of the Payments proxy
     * @param paymentsOwner The owner of the Payments implementation
     * @param paymentsSigner The signer of the Payments implementation
     * @return proxyAddr The address of the Payments proxy
     */
    function deploy(address proxyOwner, address paymentsOwner, address paymentsSigner)
        external
        returns (address proxyAddr);

    /**
     * Computes the address of a proxy instance.
     * @param proxyOwner The owner of the Payments proxy
     * @param paymentsOwner The owner of the Payments implementation
     * @param paymentsSigner The signer of the Payments implementation
     * @return proxyAddr The address of the Payments proxy
     */
    function determineAddress(address proxyOwner, address paymentsOwner, address paymentsSigner)
        external
        returns (address proxyAddr);
}

interface IPaymentsFactorySignals {
    /**
     * Event emitted when a new Payments proxy contract is deployed.
     * @param proxyAddr The address of the deployed proxy.
     */
    event PaymentsDeployed(address proxyAddr);
}

interface IPaymentsFactory is IPaymentsFactoryFunctions, IPaymentsFactorySignals {}
