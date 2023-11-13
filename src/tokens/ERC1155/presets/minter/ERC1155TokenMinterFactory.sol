// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

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
     * @param contractURI The contract URI of the ERC-1155 Token Minter proxy
     * @param royaltyReceiver Address of who should be sent the royalty payment
     * @param royaltyFeeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @return proxyAddr The address of the ERC-1155 Token Minter Proxy
     * @dev As `proxyOwner` owns the proxy, it will be unable to call the ERC-1155 Token Minter functions.
     */
    function deploy(
        address proxyOwner,
        address tokenOwner,
        string memory name,
        string memory baseURI,
        string memory contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    )
        external
        returns (address proxyAddr)
    {
        bytes32 salt = keccak256(abi.encodePacked(tokenOwner, name, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator));
        proxyAddr = _createProxy(salt, proxyOwner, "");
        ERC1155TokenMinter(proxyAddr).initialize(tokenOwner, name, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator);
        emit ERC1155TokenMinterDeployed(proxyAddr);
        return proxyAddr;
    }
}
