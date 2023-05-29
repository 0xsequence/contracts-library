// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {ERC1155Sale} from "./ERC1155Sale.sol";
import {IERC1155SaleFactory} from "./IERC1155SaleFactory.sol";
import {ProxyDeployer} from "../../proxies/ERC1967/ProxyDeployer.sol";

contract ERC1155SaleFactory is IERC1155SaleFactory, ProxyDeployer {
    address private immutable _implAddr;

    /**
     * Creates an ERC-1155 Sale Factory.
     */
    constructor() {
        ERC1155Sale proxyImpl = new ERC1155Sale();
        _implAddr = address(proxyImpl);
    }

    /**
     * Creates an ERC-1155 Sale proxy contract
     * @param _defaultAdmin The default admin role for the contract.
     * @param _name The name of the collection.
     * @param _baseURI The base URI of the collection.
     * @param _primarySaleRecipient The address to receive sale proceeds.
     * @param _royaltyRecipient The address to receive royalty payments.
     * @param _royaltyBps The royalty basis points.
     * @return proxyAddr The address of the ERC-1155 Sale Proxy
     */
    function deployERC1155Sale(
        address _defaultAdmin,
        string memory _name,
        string memory _baseURI,
        address _primarySaleRecipient,
        address _royaltyRecipient,
        uint128 _royaltyBps,
        bytes32 _salt
    )
        external
        returns (address proxyAddr)
    {
        proxyAddr = _deployProxy(_implAddr, _salt);
        ERC1155Sale(proxyAddr).initialize(
            _defaultAdmin, _name, _baseURI, _primarySaleRecipient, _royaltyRecipient, _royaltyBps
        );
        emit ERC1155SaleDeployed(proxyAddr);
        return proxyAddr;
    }
}
