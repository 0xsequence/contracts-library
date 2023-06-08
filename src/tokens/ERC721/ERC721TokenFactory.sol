// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {ERC721Token} from "./ERC721Token.sol";
import {IERC721TokenFactory} from "./IERC721TokenFactory.sol";
import {ProxyDeployer} from "../../proxies/ERC1967/ProxyDeployer.sol";

contract ERC721TokenFactory is IERC721TokenFactory, ProxyDeployer {
    address private immutable implAddr;

    /**
     * Creates an ERC-721 Token Factory.
     */
    constructor() {
        ERC721Token proxyImpl = new ERC721Token();
        implAddr = address(proxyImpl);
    }

    /**
     * Creates an ERC-721 Token proxy.
     * @param owner The owner of the ERC-721 Token proxy
     * @param name The name of the ERC-721 Token proxy
     * @param symbol The symbol of the ERC-721 Token proxy
     * @param baseURI The base URI of the ERC-721 Token proxy
     * @param salt The deployment salt
     * @return proxyAddr The address of the ERC-721 Token Proxy
     * @dev The provided `salt` is hashed with the caller address for security.
     */
    function deploy(address owner, string memory name, string memory symbol, string memory baseURI, bytes32 salt)
        external
        returns (address proxyAddr)
    {
        proxyAddr = _deployProxy(implAddr, keccak256(abi.encode(msg.sender, salt)));
        ERC721Token(proxyAddr).initialize(owner, name, symbol, baseURI);
        emit ERC721TokenDeployed(proxyAddr);
        return proxyAddr;
    }
}
