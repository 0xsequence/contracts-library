// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { ModularProxy } from "./ModularProxy.sol";

/// @title IModularProxyFactory
/// @author Michael Standen
/// @notice Factory for deploying modular proxy instances.
interface IModularProxyFactory {

    /// @notice Event emitted when a new modular proxy instance is deployed
    /// @param proxyAddr The address of the deployed proxy
    event Deployed(address proxyAddr);

    /// @notice Deploys a modular proxy instance
    /// @param nonce The nonce to use for the deployment
    /// @param defaultImpl The default implementation of the proxy
    /// @param owner The owner of the proxy
    /// @return proxy The ModularProxy instance
    function deploy(uint256 nonce, address defaultImpl, address owner) external returns (ModularProxy proxy);

    /// @notice Computes the address of a proxy instance
    /// @param nonce The nonce to use for the deployment
    /// @param defaultImpl The default implementation of the proxy
    /// @param owner The owner of the proxy
    /// @return proxyAddr The address of the modular proxy instance
    function determineAddress(uint256 nonce, address defaultImpl, address owner) external returns (address proxyAddr);

}
