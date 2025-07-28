// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { DefaultProxy } from "./DefaultProxy.sol";

/// @title IDefaultProxyFactory
/// @author Michael Standen
/// @notice Factory for deploying default proxy instances.
interface IDefaultProxyFactory {

    /// @notice Event emitted when a new default proxy instance is deployed
    /// @param proxyAddr The address of the deployed proxy
    event Deployed(address proxyAddr);

    /// @notice Deploys a default proxy instance
    /// @param nonce The nonce to use for the deployment
    /// @param defaultImpl The default implementation of the proxy
    /// @param owner The owner of the proxy
    /// @return proxy The DefaultProxy instance
    function deploy(uint256 nonce, address defaultImpl, address owner) external returns (DefaultProxy proxy);

    /// @notice Computes the address of a proxy instance
    /// @param nonce The nonce to use for the deployment
    /// @param defaultImpl The default implementation of the proxy
    /// @param owner The owner of the proxy
    /// @return proxyAddr The address of the default proxy instance
    function determineAddress(uint256 nonce, address defaultImpl, address owner) external returns (address proxyAddr);

}
