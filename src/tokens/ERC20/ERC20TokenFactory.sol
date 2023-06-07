// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {ERC20Token} from "./ERC20Token.sol";
import {IERC20TokenFactory} from "./IERC20TokenFactory.sol";
import {ProxyDeployer} from "../../proxies/ERC1967/ProxyDeployer.sol";

contract ERC20TokenFactory is IERC20TokenFactory, ProxyDeployer {
    address private immutable _implAddr;

    /**
     * Creates an ERC-20 Token Factory.
     */
    constructor() {
        ERC20Token proxyImpl = new ERC20Token();
        _implAddr = address(proxyImpl);
    }

    /**
     * Creates an ERC-20 Token proxy.
     * @param _owner The owner of the ERC-20 Token proxy
     * @param _name The name of the ERC-20 Token proxy
     * @param _symbol The symbol of the ERC-20 Token proxy
     * @param _decimals The decimals of the ERC-20 Token proxy
     * @param _salt The deployment salt
     * @return proxyAddr The address of the ERC-20 Token Proxy
     */
    function deploy(address _owner, string memory _name, string memory _symbol, uint8 _decimals, bytes32 _salt)
        external
        returns (address proxyAddr)
    {
        proxyAddr = _deployProxy(_implAddr, _salt);
        ERC20Token(proxyAddr).initialize(_owner, _name, _symbol, _decimals);
        emit ERC20TokenDeployed(proxyAddr);
        return proxyAddr;
    }
}
