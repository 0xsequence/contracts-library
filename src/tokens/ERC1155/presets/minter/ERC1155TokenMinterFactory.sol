// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {ERC1155TokenMinter} from "@0xsequence/contracts-library/tokens/ERC1155/presets/minter/ERC1155TokenMinter.sol";
import {IERC1155TokenMinterFactory} from "@0xsequence/contracts-library/tokens/ERC1155/presets/minter/IERC1155TokenMinterFactory.sol";
import {ProxyDeployer} from "@0xsequence/contracts-library/proxies/ERC1967/ProxyDeployer.sol";

contract ERC1155TokenMinterFactory is IERC1155TokenMinterFactory, ProxyDeployer {
    address private immutable implAddr;

    /**
     * Creates an ERC-1155 Token Minter Factory.
     */
    constructor() {
        ERC1155TokenMinter proxyImpl = new ERC1155TokenMinter();
        implAddr = address(proxyImpl);
    }

    /**
     * Creates an ERC-1155 Token Minter proxy.
     * @param owner The owner of the ERC-1155 Token Minter proxy
     * @param name The name of the ERC-1155 Token Minter proxy
     * @param baseURI The base URI of the ERC-1155 Token Minter proxy
     * @param salt The deployment salt
     * @return proxyAddr The address of the ERC-1155 Token Minter Proxy
     * @dev The provided `salt` is hashed with the caller address for security.
     */
    function deploy(address owner, string memory name, string memory baseURI, bytes32 salt)
        external
        returns (address proxyAddr)
    {
        proxyAddr = _deployProxy(implAddr, keccak256(abi.encode(msg.sender, salt)));
        ERC1155TokenMinter(proxyAddr).initialize(owner, name, baseURI);
        emit ERC1155TokenMinterDeployed(proxyAddr);
        return proxyAddr;
    }
}
