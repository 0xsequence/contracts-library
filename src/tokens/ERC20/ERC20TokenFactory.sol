// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {ERC20Token} from "./ERC20Token.sol";
import {IERC20TokenFactory} from "./IERC20TokenFactory.sol";
import {ProxyDeployer} from "../../proxies/ERC1967/ProxyDeployer.sol";

contract ERC20TokenFactory is IERC20TokenFactory, ProxyDeployer {
    address private immutable implAddr;

    /**
     * Creates an ERC-20 Token Factory.
     */
    constructor() {
        ERC20Token proxyImpl = new ERC20Token();
        implAddr = address(proxyImpl);
    }

    /**
     * Creates an ERC-20 Token proxy.
     * @param owner The owner of the ERC-20 Token proxy
     * @param name The name of the ERC-20 Token proxy
     * @param symbol The symbol of the ERC-20 Token proxy
     * @param decimals The decimals of the ERC-20 Token proxy
     * @param salt The deployment salt
     * @return proxyAddr The address of the ERC-20 Token Proxy
     * @dev The provided `salt` is hashed with the caller address for security.
     */
    function deploy(address owner, string memory name, string memory symbol, uint8 decimals, bytes32 salt)
        external
        returns (address proxyAddr)
    {
        proxyAddr = _deployProxy(implAddr, keccak256(abi.encode(msg.sender, salt)));
        ERC20Token(proxyAddr).initialize(owner, name, symbol, decimals);
        emit ERC20TokenDeployed(proxyAddr);
        return proxyAddr;
    }
}
