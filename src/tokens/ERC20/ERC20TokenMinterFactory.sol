// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {ERC20TokenMinter} from "./ERC20TokenMinter.sol";
import {IERC20TokenMinterFactory} from "./IERC20TokenMinterFactory.sol";
import {ProxyDeployer} from "../../proxies/ERC1967/ProxyDeployer.sol";

contract ERC20TokenMinterFactory is IERC20TokenMinterFactory, ProxyDeployer {
    address private immutable _implAddr;

    /**
     * Creates an ERC-20 Token Minter Factory.
     */
    constructor() {
        ERC20TokenMinter proxyImpl = new ERC20TokenMinter();
        _implAddr = address(proxyImpl);
    }

    /**
     * Creates an ERC-20 Token Minter proxy.
     * @param owner The owner of the ERC-20 Token Minter proxy
     * @param name The name of the ERC-20 Token Minter proxy
     * @param symbol The symbol of the ERC-20 Token Minter proxy
     * @param decimals The decimals of the ERC-20 Token Minter proxy
     * @param salt The deployment salt
     * @return proxyAddr The address of the ERC-20 Token Minter Proxy
     * @dev The provided `salt` is hashed with the caller address for security.
     */
    function deploy(address owner, string memory name, string memory symbol, uint8 decimals, bytes32 salt)
        external
        returns (address proxyAddr)
    {
        proxyAddr = _deployProxy(_implAddr, keccak256(abi.encode(msg.sender, salt)));
        ERC20TokenMinter(proxyAddr).initialize(owner, name, symbol, decimals);
        emit ERC20TokenMinterDeployed(proxyAddr);
        return proxyAddr;
    }
}
