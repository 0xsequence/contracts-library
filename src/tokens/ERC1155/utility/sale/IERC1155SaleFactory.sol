// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IERC1155SaleFactoryFunctions {

    /**
     * Creates an ERC-1155 Sale proxy contract
     * @param nonce Nonce for randomizing the deployment address.
     * @param proxyOwner The owner of the ERC-1155 Sale proxy
     * @param tokenOwner The owner of the ERC-1155 Sale implementation
     * @param items The ERC-1155 Items contract address
     * @param implicitModeValidator The implicit mode validator address
     * @param implicitModeProjectId The implicit mode project id
     * @return proxyAddr The address of the ERC-1155 Sale Proxy
     * @notice The deployed contract must be granted the MINTER_ROLE on the ERC-1155 Items contract.
     */
    function deploy(
        uint256 nonce,
        address proxyOwner,
        address tokenOwner,
        address items,
        address implicitModeValidator,
        bytes32 implicitModeProjectId
    ) external returns (address proxyAddr);

    /**
     * Computes the address of a proxy instance.
     * @param nonce Nonce for randomizing the deployment address.
     * @param proxyOwner The owner of the ERC-1155 Sale proxy
     * @param tokenOwner The owner of the ERC-1155 Sale implementation
     * @param items The ERC-1155 Items contract address
     * @param implicitModeValidator The implicit mode validator address
     * @param implicitModeProjectId The implicit mode project id
     * @return proxyAddr The address of the ERC-1155 Sale Proxy
     */
    function determineAddress(
        uint256 nonce,
        address proxyOwner,
        address tokenOwner,
        address items,
        address implicitModeValidator,
        bytes32 implicitModeProjectId
    ) external returns (address proxyAddr);

}

interface IERC1155SaleFactorySignals {

    /**
     * Event emitted when a new ERC-1155 Sale proxy contract is deployed.
     * @param proxyAddr The address of the deployed proxy.
     */
    event ERC1155SaleDeployed(address proxyAddr);

}

interface IERC1155SaleFactory is IERC1155SaleFactoryFunctions, IERC1155SaleFactorySignals { }
