// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IERC721SaleFactoryFunctions {
    /**
     * Creates an ERC-721 Sale for given token contract
     * @param proxyOwner The owner of the ERC-721 Sale proxy
     * @param tokenOwner The owner of the ERC-721 Sale implementation
     * @param items The ERC-721 Items contract address
     * @return proxyAddr The address of the ERC-721 Sale Proxy
     * @notice The deployed contract must be granted the MINTER_ROLE on the ERC-721 Items contract.
     */
    function deploy(address proxyOwner, address tokenOwner, address items) external returns (address proxyAddr);

    /**
     * Computes the address of a proxy instance.
     * @param proxyOwner The owner of the ERC-721 Sale proxy
     * @param tokenOwner The owner of the ERC-721 Sale implementation
     * @param items The ERC-721 Items contract address
     * @return proxyAddr The address of the ERC-721 Sale Proxy
     */
    function determineAddress(address proxyOwner, address tokenOwner, address items)
        external
        returns (address proxyAddr);
}

interface IERC721SaleFactorySignals {
    /**
     * Event emitted when a new ERC-721 Sale proxy contract is deployed.
     * @param proxyAddr The address of the deployed proxy.
     */
    event ERC721SaleDeployed(address proxyAddr);
}

interface IERC721SaleFactory is IERC721SaleFactoryFunctions, IERC721SaleFactorySignals {}
