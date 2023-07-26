// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

interface IERC721SaleFactoryFunctions {

    /**
     * Creates an ERC-721 Sale for given token contract
     * @param proxyOwner The owner of the ERC-721 Sale proxy
     * @param tokenOwner The owner of the ERC-721 Sale implementation
     * @param name The name of the ERC-721 Sale token
     * @param symbol The symbol of the ERC-721 Sale token
     * @param baseURI The base URI of the ERC-721 Sale token
     * @param salt The deployment salt
     * @return proxyAddr The address of the ERC-721 Sale Proxy
     * @dev As `proxyOwner` owns the proxy, it will be unable to call the ERC-721 Sale functions.
     */
    function deploy(
        address proxyOwner,
        address tokenOwner,
        string memory name,
        string memory symbol,
        string memory baseURI,
        bytes32 salt
    )
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
