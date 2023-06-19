// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

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
     * @param _owner The owner of the ERC-1155 Sale
     * @param _name The name of the ERC-1155 Sale token
     * @param _baseURI The base URI of the ERC-1155 Sale token
     * @param _salt The deployment salt
     * @return proxyAddr The address of the ERC-1155 Sale Proxy
     */
    function deployERC1155Sale(address _owner, string memory _name, string memory _baseURI, bytes32 _salt)
        external
        returns (address proxyAddr)
    {
        proxyAddr = _deployProxy(_implAddr, _salt);
        ERC1155Sale(proxyAddr).initialize(_owner, _name, _baseURI);
        emit ERC1155SaleDeployed(proxyAddr);
        return proxyAddr;
    }
}
