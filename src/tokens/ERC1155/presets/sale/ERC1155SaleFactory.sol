// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

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
     * @param contractURI The contract URI of the ERC-1155 Sale token
     * @param royaltyReceiver Address of who should be sent the royalty payment
     * @param royaltyFeeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @return proxyAddr The address of the ERC-1155 Sale Proxy
     * @dev As `proxyOwner` owns the proxy, it will be unable to call the ERC-1155 Sale functions.
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
        bytes32 salt =
            keccak256(abi.encodePacked(tokenOwner, name, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator));
        proxyAddr = _createProxy(salt, proxyOwner, "");
        ERC1155Sale(proxyAddr).initialize(tokenOwner, name, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator);
        emit ERC1155SaleDeployed(proxyAddr);
        return proxyAddr;
    }
}
