// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ERC1155Sale} from "@0xsequence/contracts-library/tokens/ERC1155/utility/sale/ERC1155Sale.sol";
import {IERC1155SaleFactory} from "@0xsequence/contracts-library/tokens/ERC1155/utility/sale/IERC1155SaleFactory.sol";
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
     * @param items The ERC-1155 Items contract address
     * @return proxyAddr The address of the ERC-1155 Sale Proxy
     * @dev As `proxyOwner` owns the proxy, it will be unable to call the ERC-1155 Sale functions.
     * @notice The deployed contract must be granted the MINTER_ROLE on the ERC-1155 Items contract.
     */
    function deploy(address proxyOwner, address tokenOwner, address items) external returns (address proxyAddr) {
        bytes32 salt = keccak256(abi.encodePacked(tokenOwner, items));
        proxyAddr = _createProxy(salt, proxyOwner, "");
        ERC1155Sale(proxyAddr).initialize(tokenOwner, items);
        emit ERC1155SaleDeployed(proxyAddr);
        return proxyAddr;
    }
}
