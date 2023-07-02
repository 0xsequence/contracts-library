// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

interface IProxyDeployerFunctions {

    /**
     * Predicts the deployed wrapper proxy address for a given implementation and salt.
     * @param implAddr The address of the proxy implementation
     * @param salt The deployment salt
     * @return proxyAddr The address of the deployed wrapper
     */
    function predictProxyAddress(address implAddr, bytes32 salt) external view returns (address proxyAddr);

    // Note deployment functions are the responsibility of inheriting contracts
}

interface IProxyDeployerSignals {

    // Note success events are the responsibility of inheriting contracts

    /**
     * Thrown when the proxy creation fails.
     */
    error ProxyCreationFailed();
}

interface IProxyDeployer is IProxyDeployerSignals {}
