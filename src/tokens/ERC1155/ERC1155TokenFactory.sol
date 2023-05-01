// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {ERC1155Token} from "./ERC1155Token.sol";
import {IERC1155TokenFactory} from "./IERC1155TokenFactory.sol";
import {ProxyDeployer} from "../../proxies/ERC1967/ProxyDeployer.sol";

contract ERC1155TokenFactory is IERC1155TokenFactory, ProxyDeployer {
    address private immutable _implAddr;

    /**
     * Creates an ERC-1155 Token Factory.
     */
    constructor() {
        ERC1155Token proxyImpl = new ERC1155Token();
        _implAddr = address(proxyImpl);
    }

    /**
     * Creates an ERC-1155 Token proxy.
     * @param _owner The owner of the ERC-1155 Token proxy
     * @param _name The name of the ERC-1155 Token proxy
     * @param _baseURI The base URI of the ERC-1155 Token proxy
     * @param _salt The deployment salt
     * @return proxyAddr The address of the ERC-1155 Token Proxy
     */
    function deploy(address _owner, string memory _name, string memory _baseURI, bytes32 _salt)
        external
        returns (address proxyAddr)
    {
        proxyAddr = _deployProxy(_implAddr, _salt);
        ERC1155Token(proxyAddr).initialize(_owner, _name, _baseURI);
        emit ERC1155TokenDeployed(proxyAddr);
        return proxyAddr;
    }
}
