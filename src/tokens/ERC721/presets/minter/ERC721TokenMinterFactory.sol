// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {ERC721TokenMinter} from "@0xsequence/contracts-library/tokens/ERC721/presets/minter/ERC721TokenMinter.sol";
import {IERC721TokenMinterFactory} from "@0xsequence/contracts-library/tokens/ERC721/presets/minter/IERC721TokenMinterFactory.sol";
import {ProxyDeployer} from "@0xsequence/contracts-library/proxies/ERC1967/ProxyDeployer.sol";

contract ERC721TokenMinterFactory is IERC721TokenMinterFactory, ProxyDeployer {
    address private immutable _implAddr;

    /**
     * Creates an ERC-721 Token Minter Factory.
     */
    constructor() {
        ERC721TokenMinter proxyImpl = new ERC721TokenMinter();
        _implAddr = address(proxyImpl);
    }

    /**
     * Creates an ERC-721 Token Minter proxy.
     * @param owner The owner of the ERC-721 Token Minter proxy
     * @param name The name of the ERC-721 Token Minter proxy
     * @param symbol The symbol of the ERC-721 Token Minter proxy
     * @param baseURI The base URI of the ERC-721 Token Minter proxy
     * @param salt The deployment salt
     * @return proxyAddr The address of the ERC-721 Token Minter Proxy
     * @dev The provided `salt` is hashed with the caller address for security.
     */
    function deploy(address owner, string memory name, string memory symbol, string memory baseURI, bytes32 salt)
        external
        returns (address proxyAddr)
    {
        proxyAddr = _deployProxy(_implAddr, keccak256(abi.encode(msg.sender, salt)));
        ERC721TokenMinter(proxyAddr).initialize(owner, name, symbol, baseURI);
        emit ERC721TokenMinterDeployed(proxyAddr);
        return proxyAddr;
    }
}
