// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {ERC721Token} from "./ERC721Token.sol";
import {IERC721TokenFactory} from "./IERC721TokenFactory.sol";
import {ProxyDeployer} from "../../proxies/ERC1967/ProxyDeployer.sol";

contract ERC721TokenFactory is IERC721TokenFactory, ProxyDeployer {
    address private immutable _implAddr;

    /**
     * Creates an ERC-721 Token Factory.
     */
    constructor() {
        ERC721Token proxyImpl = new ERC721Token();
        _implAddr = address(proxyImpl);
    }

    /**
     * Creates an ERC-721 Token proxy.
     * @param _owner The owner of the ERC-721 Token proxy
     * @param _name The name of the ERC-721 Token proxy
     * @param _symbol The symbol of the ERC-721 Token proxy
     * @param _baseURI The base URI of the ERC-721 Token proxy
     * @param _salt The deployment salt
     * @return proxyAddr The address of the ERC-721 Token Proxy
     * @dev The provided `_salt` is hashed with the caller address for security.
     */
    function deploy(address _owner, string memory _name, string memory _symbol, string memory _baseURI, bytes32 _salt)
        external
        returns (address proxyAddr)
    {
        proxyAddr = _deployProxy(_implAddr, keccak256(abi.encode(msg.sender, _salt)));
        ERC721Token(proxyAddr).initialize(_owner, _name, _symbol, _baseURI);
        emit ERC721TokenDeployed(proxyAddr);
        return proxyAddr;
    }
}
