// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

interface IERC721SaleFactory {
    /**
     * Event emitted when a new ERC-721 Drop Admin  proxy contract is deployed.
     * @param proxyAddr The address of the deployed proxy.
     */
    event ERC721SaleDeployed(address proxyAddr);

    /**
     * Creates an ERC-721 Floor Wrapper for given token contract.
     * @return proxyAddr The address of the ERC-721 Sale Proxy
     */
    function deployERC721Sale(
        address _defaultAdmin,
        string memory _name,
        string memory _symbol,
        address[] memory _trustedForwarders,
        address _saleRecipient,
        address _royaltyRecipient,
        uint128 _royaltyBps,
        bytes32 _salt
    )
        external
        returns (address proxyAddr);
}
