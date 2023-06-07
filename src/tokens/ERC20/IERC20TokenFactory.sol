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
     * @param _owner The owner of the ERC-20 Token proxy
     * @param _name The name of the ERC-20 Token proxy
     * @param _symbol The symbol of the ERC-20 Token proxy
     * @param _decimals The decimals of the ERC-20 Token proxy
     * @param _salt The deployment salt
     * @return proxyAddr The address of the ERC-20 Token Proxy
     */
    function deploy(address _owner, string memory _name, string memory _symbol, uint8 _decimals, bytes32 _salt)
        external
        returns (address proxyAddr);
}
