// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {ERC1155Sale} from "@0xsequence/contracts-library/tokens/ERC1155/presets/sale/ERC1155Sale.sol";
import {IERC1155SaleFactory} from "@0xsequence/contracts-library/tokens/ERC1155/presets/sale/IERC1155SaleFactory.sol";
import {SequenceProxyFactory} from "@0xsequence/contracts-library/proxies/SequenceProxyFactory.sol";

/**
 * Deployer of ERC-1155 Sale proxies.
 */
contract ERC1155SaleFactory is IERC1155SaleFactory, SequenceProxyFactory {
    /**
     * Creates an ERC-1155 Sale Factory.
     * @param factoryOwner The owner of the ERC-1155 Sale Factory
     */
    constructor(address factoryOwner) {
        ERC1155Sale impl = new ERC1155Sale();
        SequenceProxyFactory._initialize(address(impl), factoryOwner);
    }

    /**
     * Creates an ERC-1155 Sale proxy contract
     * @param proxyOwner The owner of the ERC-1155 Sale proxy
     * @param tokenOwner The owner of the ERC-1155 Sale implementation
     * @param name The name of the ERC-1155 Sale token
     * @param baseURI The base URI of the ERC-1155 Sale token
     * @param salt The deployment salt
     * @return proxyAddr The address of the ERC-1155 Sale Proxy
     * @dev As `proxyOwner` owns the proxy, it will be unable to call the ERC-20 Token Minter functions.
     */
    function deploy(address proxyOwner, address tokenOwner, string memory name, string memory baseURI, bytes32 salt)
        external
        returns (address proxyAddr)
    {
        proxyAddr = _createProxy(salt, proxyOwner, "");
        ERC1155Sale(proxyAddr).initialize(tokenOwner, name, baseURI);
        emit ERC1155SaleDeployed(proxyAddr);
        return proxyAddr;
    }
}
