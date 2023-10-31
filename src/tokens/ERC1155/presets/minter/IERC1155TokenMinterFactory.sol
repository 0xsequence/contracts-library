// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

interface IERC1155TokenMinterFactoryFunctions {
    /**
     * Creates an ERC-1155 Token Minter proxy.
     * @param proxyOwner The owner of the ERC-1155 Token Minter proxy
     * @param tokenOwner The owner of the ERC-1155 Token Minter implementation
     * @param name The name of the ERC-1155 Token Minter proxy
     * @param baseURI The base URI of the ERC-1155 Token Minter proxy
     * @param royaltyReceiver Address of who should be sent the royalty payment
     * @param royaltyFeeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @return proxyAddr The address of the ERC-1155 Token Minter Proxy
     * @dev As `proxyOwner` owns the proxy, it will be unable to call the ERC-1155 Token Minter functions.
     */
    function deploy(
        address proxyOwner,
        address tokenOwner,
        string memory name,
        string memory baseURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    )
        external
        returns (address proxyAddr);
}

interface IERC1155TokenMinterFactorySignals {
    /**
     * Event emitted when a new ERC-1155 Token Minter proxy contract is deployed.
     * @param proxyAddr The address of the deployed proxy.
     */
    event ERC1155TokenMinterDeployed(address proxyAddr);
}

interface IERC1155TokenMinterFactory is IERC1155TokenMinterFactoryFunctions, IERC1155TokenMinterFactorySignals {}
