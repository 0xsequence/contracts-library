// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

interface IERC1155PackedTokenFactory {
    /**
     * Event emitted when a new ERC-1155 Packed Token proxy contract is deployed.
     * @param proxyAddr The address of the deployed proxy.
     */
    event ERC1155PackedTokenDeployed(address proxyAddr);

    /**
     * Creates an ERC-1155 Packed Token proxy.
     * @param _owner The owner of the ERC-1155 Packed Token proxy
     * @param _name The name of the ERC-1155 Packed Token proxy
     * @param _baseURI The base URI of the ERC-1155 Packed Token proxy
     * @param _salt The deployment salt
     * @return proxyAddr The address of the ERC-1155 Packed Token Proxy
     */
    function deploy(address _owner, string memory _name, string memory _baseURI, bytes32 _salt)
        external
        returns (address proxyAddr);
}
