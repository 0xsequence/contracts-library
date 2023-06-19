// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {ERC1155PackedToken} from "./ERC1155PackedToken.sol";
import {IERC1155PackedTokenFactory} from "./IERC1155PackedTokenFactory.sol";
import {ProxyDeployer} from "../../../proxies/ERC1967/ProxyDeployer.sol";

contract ERC1155PackedTokenFactory is IERC1155PackedTokenFactory, ProxyDeployer {
    address private immutable _implAddr;

    /**
     * Creates an ERC-1155 Token Factory.
     */
    constructor() {
        ERC1155PackedToken proxyImpl = new ERC1155PackedToken();
        _implAddr = address(proxyImpl);
    }

    /**
     * Creates an ERC-1155 Packed Token proxy.
     * @param owner The owner of the ERC-1155 Packed Token proxy
     * @param name The name of the ERC-1155 Packed Token proxy
     * @param baseURI The base URI of the ERC-1155 Packed Token proxy
     * @param salt The deployment salt
     * @return proxyAddr The address of the ERC-1155 Packed Token Proxy
     * @dev The provided `salt` is hashed with the caller address for security.
     */
    function deploy(address owner, string memory name, string memory baseURI, bytes32 salt)
        external
        returns (address proxyAddr)
    {
        proxyAddr = _deployProxy(_implAddr, keccak256(abi.encode(msg.sender, salt)));
        ERC1155PackedToken(proxyAddr).initialize(owner, name, baseURI);
        emit ERC1155PackedTokenDeployed(proxyAddr);
        return proxyAddr;
    }
}
