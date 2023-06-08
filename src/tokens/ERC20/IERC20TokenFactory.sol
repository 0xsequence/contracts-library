// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

interface IERC20TokenFactory {
    /**
     * Event emitted when a new ERC-20 Token proxy contract is deployed.
     * @param proxyAddr The address of the deployed proxy.
     */
    event ERC20TokenDeployed(address proxyAddr);

    /**
     * Creates an ERC-20 Token proxy.
     * @param owner The owner of the ERC-20 Token proxy
     * @param name The name of the ERC-20 Token proxy
     * @param symbol The symbol of the ERC-20 Token proxy
     * @param decimals The decimals of the ERC-20 Token proxy
     * @param salt The deployment salt
     * @return proxyAddr The address of the ERC-20 Token Proxy
     */
    function deploy(address owner, string memory name, string memory symbol, uint8 decimals, bytes32 salt)
        external
        returns (address proxyAddr);
}
