// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IERC20ItemsFactoryFunctions {
    /**
     * Creates an ERC-20 Items proxy.
     * @param proxyOwner The owner of the ERC-20 Items proxy
     * @param tokenOwner The owner of the ERC-20 Items implementation
     * @param name The name of the ERC-20 Items proxy
     * @param symbol The symbol of the ERC-20 Items proxy
     * @param decimals The decimals of the ERC-20 Items proxy
     * @return proxyAddr The address of the ERC-20 Items Proxy
     */
    function deploy(address proxyOwner, address tokenOwner, string memory name, string memory symbol, uint8 decimals)
        external
        returns (address proxyAddr);

    /**
     * Computes the address of a proxy instance.
     * @param proxyOwner The owner of the ERC-20 Items proxy
     * @param tokenOwner The owner of the ERC-20 Items implementation
     * @param name The name of the ERC-20 Items proxy
     * @param symbol The symbol of the ERC-20 Items proxy
     * @param decimals The decimals of the ERC-20 Items proxy
     * @return proxyAddr The address of the ERC-20 Items Proxy
     */
    function determineAddress(
        address proxyOwner,
        address tokenOwner,
        string memory name,
        string memory symbol,
        uint8 decimals
    ) external view returns (address proxyAddr);
}

interface IERC20ItemsFactorySignals {
    /**
     * Event emitted when a new ERC-20 Items proxy contract is deployed.
     * @param proxyAddr The address of the deployed proxy.
     */
    event ERC20ItemsDeployed(address proxyAddr);
}

interface IERC20ItemsFactory is IERC20ItemsFactoryFunctions, IERC20ItemsFactorySignals {}
