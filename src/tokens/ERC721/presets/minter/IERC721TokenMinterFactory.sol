// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

interface IERC721TokenMinterFactoryFunctions {

    /**
     * Creates an ERC-721 Token Minter proxy.
     * @param owner The owner of the ERC-721 Token Minter proxy
     * @param name The name of the ERC-721 Token Minter proxy
     * @param symbol The symbol of the ERC-721 Token Minter proxy
     * @param baseURI The base URI of the ERC-721 Token Minter proxy
     * @param salt The deployment salt
     * @return proxyAddr The address of the ERC-721 Token Minter Proxy
     */
    function deploy(address owner, string memory name, string memory symbol, string memory baseURI, bytes32 salt)
        external
        returns (address proxyAddr);
}

interface IERC721TokenMinterFactorySignalss {
    /**
     * Event emitted when a new ERC-721 Token Minter proxy contract is deployed.
     * @param proxyAddr The address of the deployed proxy.
     */
    event ERC721TokenMinterDeployed(address proxyAddr);
}

interface IERC721TokenMinterFactory is IERC721TokenMinterFactoryFunctions, IERC721TokenMinterFactorySignalss {}
