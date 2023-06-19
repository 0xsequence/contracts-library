// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {ERC721Sale} from "./ERC721Sale.sol";
import {IERC721SaleFactory} from "./IERC721SaleFactory.sol";
import {ProxyDeployer} from "../../proxies/ERC1967/ProxyDeployer.sol";

contract ERC721SaleFactory is IERC721SaleFactory, ProxyDeployer {
    address private immutable _implAddr;

    /**
     * Creates an ERC-721 Sale Factory.
     */
    constructor() {
        ERC721Sale proxyImpl = new ERC721Sale();
        _implAddr = address(proxyImpl);
    }

    /**
     * Creates an ERC-721 Floor Wrapper for given token contract
     * @param _owner The owner of the ERC-721 Sale
     * @param _name The name of the ERC-721 Sale token
     * @param _symbol The symbol of the ERC-721 Sale token
     * @param _baseURI The base URI of the ERC-721 Sale token
     * @param _salt The deployment salt
     * @return proxyAddr The address of the ERC-721 Sale Proxy
     */
    function deployERC721Sale(
        address _owner,
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        bytes32 _salt
    )
        external
        returns (address proxyAddr)
    {
        proxyAddr = _deployProxy(_implAddr, _salt);
        ERC721Sale(proxyAddr).initialize(_owner, _name, _symbol, _baseURI);
        emit ERC721SaleDeployed(proxyAddr);
        return proxyAddr;
    }
}
