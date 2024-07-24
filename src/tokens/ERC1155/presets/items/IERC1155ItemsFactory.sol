// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IERC1155ItemsFactoryFunctions {
    /**
     * Creates an ERC-1155 Items proxy.
     * @param proxyOwner The owner of the ERC-1155 Items proxy
     * @param tokenOwner The owner of the ERC-1155 Items implementation
     * @param name The name of the ERC-1155 Items proxy
     * @param baseURI The base URI of the ERC-1155 Items proxy
     * @param contractURI The contract URI of the ERC-1155 Items proxy
     * @param royaltyReceiver Address of who should be sent the royalty payment
     * @param royaltyFeeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @return proxyAddr The address of the ERC-1155 Items Proxy
     */
    function deploy(
        address proxyOwner,
        address tokenOwner,
        string memory name,
        string memory baseURI,
        string memory contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) external returns (address proxyAddr);

    /**
     * Computes the address of a proxy instance.
     * @param proxyOwner The owner of the ERC-1155 Items proxy
     * @param tokenOwner The owner of the ERC-1155 Items implementation
     * @param name The name of the ERC-1155 Items proxy
     * @param baseURI The base URI of the ERC-1155 Items proxy
     * @param contractURI The contract URI of the ERC-1155 Items proxy
     * @param royaltyReceiver Address of who should be sent the royalty payment
     * @param royaltyFeeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @return proxyAddr The address of the ERC-1155 Items Proxy
     */
    function determineAddress(
        address proxyOwner,
        address tokenOwner,
        string memory name,
        string memory baseURI,
        string memory contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) external returns (address proxyAddr);
}

interface IERC1155ItemsFactorySignals {
    /**
     * Event emitted when a new ERC-1155 Items proxy contract is deployed.
     * @param proxyAddr The address of the deployed proxy.
     */
    event ERC1155ItemsDeployed(address proxyAddr);
}

interface IERC1155ItemsFactory is IERC1155ItemsFactoryFunctions, IERC1155ItemsFactorySignals {}
