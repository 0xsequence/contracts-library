// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IERC1155SaleFactoryFunctions {
    /**
     * Creates an ERC-1155 Sale proxy contract
     * @param proxyOwner The owner of the ERC-1155 Sale proxy
     * @param tokenOwner The owner of the ERC-1155 Sale implementation
     * @param name The name of the ERC-1155 Sale token
     * @param baseURI The base URI of the ERC-1155 Sale token
     * @param contractURI The contract URI of the ERC-1155 Sale token
     * @param royaltyReceiver Address of who should be sent the royalty payment
     * @param royaltyFeeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @return proxyAddr The address of the ERC-1155 Sale Proxy
     * @dev As `proxyOwner` owns the proxy, it will be unable to call the ERC-1155 Token Sale functions.
     */
    function deploy(
        address proxyOwner,
        address tokenOwner,
        string memory name,
        string memory baseURI,
        string memory contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    )
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
