// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { TestHelper } from "../../../TestHelper.sol";

import { AccessControl, IAccessControl } from "src/modular/modules/accessControl/AccessControl.sol";

import { ERC721 } from "src/modular/bases/erc721/ERC721.sol";
import {
    ISignalsImplicitModeControlled,
    SignalsImplicitModeControlled
} from "src/modular/modules/implicitSignals/SignalsImplicitModeControlled.sol";
import { ModularProxy } from "src/modular/modules/modularProxy/ModularProxy.sol";
import { ModularProxyFactory } from "src/modular/modules/modularProxy/ModularProxyFactory.sol";
import { ERC721ItemsExtension } from "src/modular/modules/tokens/erc721/items/ERC721ItemsExtension.sol";
import { ERC721Soulbound as SoulboundExtension } from "src/modular/modules/tokens/erc721/soulbound/ERC721Soulbound.sol";
import { ERC2981Controlled } from "src/modular/modules/tokens/royalty/ERC2981Controlled.sol";
import { IERC721ItemsFunctions, IERC721ItemsSignals } from "src/tokens/ERC721/presets/items/IERC721Items.sol";

import { ERC721Soulbound } from "src/tokens/ERC721/presets/soulbound/ERC721Soulbound.sol";
import {
    IERC721Soulbound,
    IERC721SoulboundFunctions,
    IERC721SoulboundSignals
} from "src/tokens/ERC721/presets/soulbound/IERC721Soulbound.sol";

import { IERC721 } from "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import { IERC721Metadata } from "openzeppelin-contracts/contracts/interfaces/IERC721Metadata.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";
import { IERC165 } from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

import { ISignalsImplicitMode } from "signals-implicit-mode/src/helper/SignalsImplicitMode.sol";

contract ERC721SoulboundTest is TestHelper, IERC721ItemsSignals, IERC721SoulboundSignals {

    // Redeclare events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    ERC721Soulbound private token;

    address private proxyOwner;
    address private owner;

    function setUp() public {
        owner = makeAddr("owner");

        ERC721 erc721Impl = new ERC721();
        ModularProxyFactory factory = new ModularProxyFactory();
        ModularProxy proxy = factory.deploy(0, address(erc721Impl), owner);
        address this_ = address(this);
        // Add each extension to match original ERC721Soulbound functions
        vm.startPrank(owner);
        proxy.attachModule(new AccessControl(), abi.encodePacked(owner));
        proxy.attachModule(new ERC721ItemsExtension(), abi.encodePacked(owner, owner));
        proxy.attachModule(new ERC2981Controlled(), abi.encodePacked(owner, this_, uint96(0)));
        proxy.attachModule(new SignalsImplicitModeControlled(), abi.encodePacked(owner));
        proxy.attachModule(new SoulboundExtension(), abi.encodePacked(owner));
        vm.stopPrank();
        token = ERC721Soulbound(address(proxy));
    }

    function testSupportsInterface() public view {
        assertTrue(token.supportsInterface(type(IERC165).interfaceId), "IERC165");
        assertTrue(token.supportsInterface(type(IERC721).interfaceId), "IERC721");
        assertTrue(token.supportsInterface(type(IERC721Metadata).interfaceId), "IERC721Metadata");
        assertTrue(token.supportsInterface(type(IERC721ItemsFunctions).interfaceId), "IERC721ItemsFunctions");
        assertTrue(token.supportsInterface(type(IERC721SoulboundFunctions).interfaceId), "IERC721SoulboundFunctions");
        assertTrue(token.supportsInterface(type(ISignalsImplicitMode).interfaceId), "ISignalsImplicitMode");
        assertTrue(
            token.supportsInterface(type(ISignalsImplicitModeControlled).interfaceId), "ISignalsImplicitModeControlled"
        );
    }

    function testOwnerHasRoles() public view {
        assertTrue(token.hasRole(bytes32(0), owner));
        assertTrue(token.hasRole(keccak256("TRANSFER_ADMIN_ROLE"), owner));
        // assertTrue(token.hasRole(keccak256("METADATA_ADMIN_ROLE"), owner));
        assertTrue(token.hasRole(keccak256("MINTER_ROLE"), owner));
        // assertTrue(token.hasRole(keccak256("ROYALTY_ADMIN_ROLE"), owner));
        assertTrue(token.hasRole(keccak256("IMPLICIT_MODE_ADMIN_ROLE"), owner));
    }

    //
    // Transfers
    //
    function testUnlockInvalidRole(
        address invalid
    ) public {
        vm.assume(invalid != owner);

        vm.expectRevert();
        vm.prank(invalid);
        token.setTransferLocked(false);
    }

    function testTransferLocked(address holder, address receiver, uint256 tokenId) public {
        vm.assume(holder != receiver);
        assumeSafeAddress(holder);
        assumeSafeAddress(receiver);

        vm.prank(owner);
        token.mint(holder, tokenId);

        vm.expectRevert(TransfersLocked.selector);
        vm.prank(holder);
        token.transferFrom(holder, receiver, tokenId);
    }

    function testTransferLockedOperator(address holder, address operator, address receiver, uint256 tokenId) public {
        vm.assume(holder != receiver);
        vm.assume(holder != operator);
        assumeSafeAddress(holder);
        assumeSafeAddress(operator);
        assumeSafeAddress(receiver);

        vm.prank(owner);
        token.mint(holder, tokenId);

        vm.prank(holder);
        token.setApprovalForAll(operator, true);

        vm.expectRevert(TransfersLocked.selector);
        vm.prank(operator);
        token.transferFrom(holder, receiver, tokenId);
    }

    function testTransferUnlocked(address holder, address receiver, uint256 tokenId) public {
        vm.assume(holder != receiver);
        assumeSafeAddress(holder);
        assumeSafeAddress(receiver);

        vm.prank(owner);
        token.mint(holder, tokenId);

        vm.prank(owner);
        token.setTransferLocked(false);

        vm.prank(holder);
        token.transferFrom(holder, receiver, tokenId);

        vm.assertEq(token.ownerOf(tokenId), receiver);
    }

    function testTransferUnlockedOperator(address holder, address operator, address receiver, uint256 tokenId) public {
        vm.assume(holder != receiver);
        vm.assume(holder != operator);
        assumeSafeAddress(holder);
        assumeSafeAddress(operator);
        assumeSafeAddress(receiver);

        vm.prank(owner);
        token.mint(holder, tokenId);

        vm.prank(owner);
        token.setTransferLocked(false);

        vm.prank(holder);
        token.setApprovalForAll(operator, true);

        vm.prank(operator);
        token.transferFrom(holder, receiver, tokenId);

        vm.assertEq(token.ownerOf(tokenId), receiver);
    }

}
