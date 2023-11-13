// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IERC20TokenMinterFactoryFunctions {
    /**
     * Creates an ERC-20 Token Minter proxy.
     * @param proxyOwner The owner of the ERC-20 Token Minter proxy
     * @param tokenOwner The owner of the ERC-20 Token Minter implementation
     * @param name The name of the ERC-20 Token Minter proxy
     * @param symbol The symbol of the ERC-20 Token Minter proxy
     * @param decimals The decimals of the ERC-20 Token Minter proxy
     * @return proxyAddr The address of the ERC-20 Token Minter Proxy
     * @dev As `proxyOwner` owns the proxy, it will be unable to call the ERC-20 Token Minter functions.
     */
    function deploy(address proxyOwner, address tokenOwner, string memory name, string memory symbol, uint8 decimals)
        external
        returns (address proxyAddr);
}

interface IERC20TokenMinterFactorySignals {
    /**
     * Event emitted when a new ERC-20 Token Minter proxy contract is deployed.
     * @param proxyAddr The address of the deployed proxy.
     */
    event ERC20TokenMinterDeployed(address proxyAddr);
}

interface IERC20TokenMinterFactory is IERC20TokenMinterFactoryFunctions, IERC20TokenMinterFactorySignals {}
