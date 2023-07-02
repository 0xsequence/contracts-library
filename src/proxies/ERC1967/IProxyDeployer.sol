// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

interface IProxyDeployerSignals {
    error ProxyCreationFailed();
}

interface IProxyDeployer is IProxyDeployerSignals {}
