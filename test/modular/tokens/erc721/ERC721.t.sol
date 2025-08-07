// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

// solhint-disable func-name-mixedcase

import { Test } from "forge-std/Test.sol";

import { ERC721 as SoladyERC721 } from "lib/solady/src/tokens/ERC721.sol";
import { LibString } from "lib/solady/src/utils/LibString.sol";
import { ERC721 } from "src/modular/bases/erc721/ERC721.sol";
import { AccessControl } from "src/modular/modules/accessControl/AccessControl.sol";
import { ModularProxy } from "src/modular/modules/modularProxy/ModularProxy.sol";
import { ModularProxyFactory } from "src/modular/modules/modularProxy/ModularProxyFactory.sol";
import { ERC721Burn } from "src/modular/modules/tokens/erc721/burn/ERC721Burn.sol";
import { ERC721MintAccessControl } from "src/modular/modules/tokens/erc721/mint/ERC721MintAccessControl.sol";

contract ERC721Test is Test {

    ERC721 public erc721;

    function setUp() public {
        ERC721 erc721Impl = new ERC721();
        ModularProxyFactory factory = new ModularProxyFactory();
        ModularProxy proxy = factory.deploy(0, address(erc721Impl), address(this));
        erc721 = ERC721(address(proxy));
    }

    modifier withMint() {
        AccessControl accessControl = new AccessControl();
        ModularProxy(payable(address(erc721))).attachModule(accessControl, abi.encodePacked(address(this)));
        AccessControl(address(erc721)).grantRole(keccak256("MINTER_ROLE"), address(this));
        ERC721MintAccessControl mintAccessControl = new ERC721MintAccessControl();
        ModularProxy(payable(address(erc721))).attachModule(mintAccessControl, "");
        _;
    }

    modifier withBurn() {
        ERC721Burn burn = new ERC721Burn();
        ModularProxy(payable(address(erc721))).attachModule(burn, "");
        _;
    }

    function test_erc721_setMetadata(
        string memory name,
        string memory symbol,
        string memory baseURI,
        string memory contractURI,
        uint256 tokenId
    ) public withMint {
        vm.assume(tokenId < 0xffffffff);
        vm.assume(bytes(baseURI).length > 0);

        erc721.setNameAndSymbol(name, symbol);
        erc721.setBaseMetadataURI(baseURI);
        erc721.setContractURI(contractURI);

        assertEq(erc721.name(), name);
        assertEq(erc721.symbol(), symbol);
        assertEq(erc721.contractURI(), contractURI);

        ERC721MintAccessControl(address(erc721)).mint(address(this), tokenId);

        assertEq(erc721.tokenURI(tokenId), LibString.concat(baseURI, LibString.toString(tokenId)));
    }

    function test_erc721_tokenURI_notExists(
        uint256 tokenId
    ) public {
        vm.assume(tokenId < 0xffffffff);
        vm.expectRevert(abi.encodeWithSelector(SoladyERC721.TokenDoesNotExist.selector, tokenId));
        erc721.tokenURI(tokenId);
    }

    function test_erc721_mint(address to, uint256 tokenId) public withMint {
        vm.assume(tokenId < 0xffffffff);
        vm.assume(to != address(0));

        vm.expectEmit(true, true, true, true, address(erc721));
        emit SoladyERC721.Transfer(address(0), to, tokenId);
        ERC721MintAccessControl(address(erc721)).mint(to, tokenId);

        assertEq(erc721.ownerOf(tokenId), to);
    }

    function test_erc721_burn(address to, uint256 tokenId) public withMint withBurn {
        vm.assume(tokenId < 0xffffffff);
        vm.assume(to != address(0));

        vm.expectEmit(true, true, true, true, address(erc721));
        emit SoladyERC721.Transfer(address(0), to, tokenId);
        ERC721MintAccessControl(address(erc721)).mint(to, tokenId);

        vm.expectEmit(true, true, true, true, address(erc721));
        emit SoladyERC721.Transfer(to, address(0), tokenId);
        vm.prank(to);
        ERC721Burn(address(erc721)).burn(tokenId);

        vm.expectRevert(abi.encodeWithSelector(SoladyERC721.TokenDoesNotExist.selector, tokenId));
        ERC721Burn(address(erc721)).burn(tokenId);
    }

}
