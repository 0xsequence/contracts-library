// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {ERC1155TokenMinter} from "@0xsequence/contracts-library/tokens/ERC1155/presets/minter/ERC1155TokenMinter.sol";
import {IERC1155TokenMinterFactory} from
    "@0xsequence/contracts-library/tokens/ERC1155/presets/minter/IERC1155TokenMinterFactory.sol";
import {SequenceProxyFactory} from "@0xsequence/contracts-library/proxies/SequenceProxyFactory.sol";

/**
 * Deployer of ERC-1155 Token Minter proxies.
 */
contract ERC1155TokenMinterFactory is IERC1155TokenMinterFactory, SequenceProxyFactory {
    /**
     * Creates an ERC-1155 Token Minter Factory.
     * @param factoryOwner The owner of the ERC-1155 Token Minter Factory
     */
    constructor(address factoryOwner) {
        ERC1155TokenMinter impl = new ERC1155TokenMinter();
        SequenceProxyFactory._initialize(address(impl), factoryOwner);
    }

    /**
     * Creates an ERC-1155 Token Minter proxy.
     * @param proxyOwner The owner of the ERC-1155 Token Minter proxy
     * @param tokenOwner The owner of the ERC-1155 Token Minter implementation
     * @param name The name of the ERC-1155 Token Minter proxy
     * @param baseURI The base URI of the ERC-1155 Token Minter proxy
     * @param salt The deployment salt
     * @return proxyAddr The address of the ERC-1155 Token Minter Proxy
     * @dev The provided `salt` is hashed with the caller address for security.
     * @dev As `proxyOwner` owns the proxy, it will be unable to call the ERC-20 Token Minter functions.
     */
    function deploy(address proxyOwner, address tokenOwner, string memory name, string memory baseURI, bytes32 salt)
        external
        returns (address proxyAddr)
    {
        proxyAddr = _createProxy(salt, proxyOwner, "");
        ERC1155TokenMinter(proxyAddr).initialize(tokenOwner, name, baseURI);
        emit ERC1155TokenMinterDeployed(proxyAddr);
        return proxyAddr;
    }
}
