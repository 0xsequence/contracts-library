// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IERC1155LootboxFactoryFunctions {
    /**
     * Creates an ERC-1155 Lootbox proxy.
     * @param proxyOwner The owner of the ERC-1155 Lootbox proxy
     * @param tokenOwner The owner of the ERC-1155 Lootbox implementation
     * @param name The name of the ERC-1155 Lootbox proxy
     * @param baseURI The base URI of the ERC-1155 Lootbox proxy
     * @param contractURI The contract URI of the ERC-1155 Lootbox proxy
     * @param royaltyReceiver Address of who should be sent the royalty payment
     * @param royaltyFeeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @return proxyAddr The address of the ERC-1155 Lootbox Proxy
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
     * @param proxyOwner The owner of the ERC-1155 Lootbox proxy
     * @param tokenOwner The owner of the ERC-1155 Lootbox implementation
     * @param name The name of the ERC-1155 Lootbox proxy
     * @param baseURI The base URI of the ERC-1155 Lootbox proxy
     * @param contractURI The contract URI of the ERC-1155 Lootbox proxy
     * @param royaltyReceiver Address of who should be sent the royalty payment
     * @param royaltyFeeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @return proxyAddr The address of the ERC-1155 Lootbox Proxy
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

interface IERC1155LootboxFactorySignals {
    /**
     * Event emitted when a new ERC-1155 Lootbox proxy contract is deployed.
     * @param proxyAddr The address of the deployed proxy.
     */
    event ERC1155LootboxDeployed(address proxyAddr);
}

interface IERC1155LootboxFactory is IERC1155LootboxFactoryFunctions, IERC1155LootboxFactorySignals {}
