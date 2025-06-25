// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IERC1155PackFactoryFunctions {

    /**
     * Creates an ERC-1155 Pack proxy.
     * @param proxyOwner The owner of the ERC-1155 Pack proxy
     * @param tokenOwner The owner of the ERC-1155 Pack implementation
     * @param name The name of the ERC-1155 Pack proxy
     * @param baseURI The base URI of the ERC-1155 Pack proxy
     * @param contractURI The contract URI of the ERC-1155 Pack proxy
     * @param royaltyReceiver Address of who should be sent the royalty payment
     * @param royaltyFeeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @param implicitModeValidator The implicit mode validator address
     * @param implicitModeProjectId The implicit mode project id
     * @return proxyAddr The address of the ERC-1155 Pack Proxy
     */
    function deploy(
        address proxyOwner,
        address tokenOwner,
        string memory name,
        string memory baseURI,
        string memory contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        address implicitModeValidator,
        bytes32 implicitModeProjectId
    ) external returns (address proxyAddr);

    /**
     * Computes the address of a proxy instance.
     * @param proxyOwner The owner of the ERC-1155 Pack proxy
     * @param tokenOwner The owner of the ERC-1155 Pack implementation
     * @param name The name of the ERC-1155 Pack proxy
     * @param baseURI The base URI of the ERC-1155 Pack proxy
     * @param contractURI The contract URI of the ERC-1155 Pack proxy
     * @param royaltyReceiver Address of who should be sent the royalty payment
     * @param royaltyFeeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @param implicitModeValidator The implicit mode validator address
     * @param implicitModeProjectId The implicit mode project id
     * @return proxyAddr The address of the ERC-1155 Pack Proxy
     */
    function determineAddress(
        address proxyOwner,
        address tokenOwner,
        string memory name,
        string memory baseURI,
        string memory contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        address implicitModeValidator,
        bytes32 implicitModeProjectId
    ) external returns (address proxyAddr);

}

interface IERC1155PackFactorySignals {

    /**
     * Event emitted when a new ERC-1155 Pack proxy contract is deployed.
     * @param proxyAddr The address of the deployed proxy.
     */
    event ERC1155PackDeployed(address proxyAddr);

}

interface IERC1155PackFactory is IERC1155PackFactoryFunctions, IERC1155PackFactorySignals { }
