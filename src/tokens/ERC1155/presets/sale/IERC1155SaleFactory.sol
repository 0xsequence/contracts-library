// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

interface IERC1155SaleFactoryFunctions {

    /**
     * Creates an ERC-1155 Sale proxy contract
     * @param owner The owner of the ERC-1155 Sale
     * @param name The name of the ERC-1155 Sale token
     * @param baseURI The base URI of the ERC-1155 Sale token
     * @param salt The deployment salt
     * @return proxyAddr The address of the ERC-1155 Sale Proxy
     */
    function deployERC1155Sale(address owner, string memory name, string memory baseURI, bytes32 salt)
        external
        returns (address proxyAddr);
}

interface IERC1155SaleFactorySignals {
    /**
     * Event emitted when a new ERC-1155 Sale proxy contract is deployed.
     * @param proxyAddr The address of the deployed proxy.
     */
    event ERC1155SaleDeployed(address proxyAddr);

}

interface IERC1155SaleFactory is IERC1155SaleFactoryFunctions, IERC1155SaleFactorySignals {}
