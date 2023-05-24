// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.4;

import {ERC721Sale} from "./ERC721Sale.sol";
import {IERC721SaleFactory} from "./IERC721SaleFactory.sol";
import {ProxyUpgradeableDeployer} from "../../proxies/ERC1967/ProxyUpgradeableDeployer.sol";

contract ERC721SaleFactory is IERC721SaleFactory, ProxyUpgradeableDeployer {
    address private immutable _implAddr;

    /**
     * Creates an ERC-721 Drop Admin Factory.
     */
    constructor() {
        ERC721Sale proxyImpl = new ERC721Sale();
        _implAddr = address(proxyImpl);
    }

    /**
     * Creates an ERC-721 Floor Wrapper for given token contract.
     * @return proxyAddr The address of the ERC-721 Sale Proxy
     */
    function deployERC721Sale(
        address _defaultAdmin,
        string memory _name,
        string memory _symbol,
        address[] memory _trustedForwarders,
        address _saleRecipient,
        address _royaltyRecipient,
        uint128 _royaltyBps,
        bytes32 _salt
    )
        external
        returns (address proxyAddr)
    {
        proxyAddr = _deployProxy(_implAddr, _salt, _defaultAdmin);
        ERC721Sale(proxyAddr).initialize(
            _defaultAdmin, _name, _symbol, _trustedForwarders, _saleRecipient, _royaltyRecipient, _royaltyBps
        );
        emit ERC721SaleDeployed(proxyAddr);
        return proxyAddr;
    }
}
