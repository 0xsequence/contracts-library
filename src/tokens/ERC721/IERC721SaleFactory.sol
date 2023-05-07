// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

interface IERC721SaleFactory {
    /**
     * Event emitted when a new ERC-721 Sale proxy contract is deployed.
     * @param proxyAddr The address of the deployed proxy.
     */
    event ERC721SaleDeployed(address proxyAddr);
}
