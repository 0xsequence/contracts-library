// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {IERC721TokenMinterFactory} from
    "@0xsequence/contracts-library/tokens/ERC721/presets/minter/IERC721TokenMinterFactory.sol";
import {ERC721TokenMinter} from "@0xsequence/contracts-library/tokens/ERC721/presets/minter/ERC721TokenMinter.sol";
import {SequenceProxyFactory} from "@0xsequence/contracts-library/proxies/SequenceProxyFactory.sol";

/**
 * Deployer of ERC-721 Token Minter proxies.
 */
contract ERC721TokenMinterFactory is IERC721TokenMinterFactory, SequenceProxyFactory {
    /**
     * Creates an ERC-721 Token Minter Factory.
     * @param factoryOwner The owner of the ERC-721 Token Minter Factory
     */
    constructor(address factoryOwner) {
        ERC721TokenMinter impl = new ERC721TokenMinter();
        SequenceProxyFactory._initialize(address(impl), factoryOwner);
    }

    /**
     * Creates an ERC-721 Token Minter proxy.
     * @param proxyOwner The owner of the ERC-721 Token Minter proxy
     * @param tokenOwner The owner of the ERC-721 Token Minter implementation
     * @param name The name of the ERC-721 Token Minter proxy
     * @param symbol The symbol of the ERC-721 Token Minter proxy
     * @param baseURI The base URI of the ERC-721 Token Minter proxy
     * @param royaltyReceiver Address of who should be sent the royalty payment
     * @param royaltyFeeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @return proxyAddr The address of the ERC-721 Token Minter Proxy
     * @dev As `proxyOwner` owns the proxy, it will be unable to call the ERC-721 Token Minter functions.
     */
    function deploy(
        address proxyOwner,
        address tokenOwner,
        string memory name,
        string memory symbol,
        string memory baseURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    )
        external
        returns (address proxyAddr)
    {
        bytes32 salt =
            keccak256(abi.encodePacked(tokenOwner, name, symbol, baseURI, royaltyReceiver, royaltyFeeNumerator));
        proxyAddr = _createProxy(salt, proxyOwner, "");
        ERC721TokenMinter(proxyAddr).initialize(tokenOwner, name, symbol, baseURI, royaltyReceiver, royaltyFeeNumerator);
        emit ERC721TokenMinterDeployed(proxyAddr);
        return proxyAddr;
    }
}
