// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { TestHelper } from "../../../TestHelper.sol";

import { IERC721ItemsFunctions, IERC721ItemsSignals } from "src/tokens/ERC721/presets/items/IERC721Items.sol";
import { ERC721Soulbound } from "src/tokens/ERC721/presets/soulbound/ERC721Soulbound.sol";

import { ERC721SoulboundFactory } from "src/tokens/ERC721/presets/soulbound/ERC721SoulboundFactory.sol";
import {
    IERC721Soulbound,
    IERC721SoulboundFunctions,
    IERC721SoulboundSignals
} from "src/tokens/ERC721/presets/soulbound/IERC721Soulbound.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// Interfaces
import { IERC165 } from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";

import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IERC721Metadata } from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import { IERC721AQueryable } from "erc721a/contracts/extensions/IERC721AQueryable.sol";
import { IERC721A } from "erc721a/contracts/interfaces/IERC721A.sol";

contract ERC721SoulboundTest is TestHelper, IERC721ItemsSignals, IERC721SoulboundSignals {

    // Redeclare events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    ERC721Soulbound private token;

    address private proxyOwner;
    address private owner;

    function setUp() public {
        owner = makeAddr("owner");
        proxyOwner = makeAddr("proxyOwner");

        vm.deal(address(this), 100 ether);
        vm.deal(owner, 100 ether);

        ERC721SoulboundFactory factory = new ERC721SoulboundFactory(address(this));
        token = ERC721Soulbound(
            factory.deploy(proxyOwner, owner, "name", "symbol", "baseURI", "contractURI", address(this), 0)
        );
    }

    function testReinitializeFails() public {
        vm.expectRevert(InvalidInitialization.selector);
        token.initialize(owner, "name", "symbol", "baseURI", "contractURI", address(this), 0);
    }

    function testSupportsInterface() public view {
        assertTrue(token.supportsInterface(type(IERC165).interfaceId));
        assertTrue(token.supportsInterface(type(IERC721A).interfaceId));
        assertTrue(token.supportsInterface(type(IERC721AQueryable).interfaceId));
        assertTrue(token.supportsInterface(type(IERC721).interfaceId));
        assertTrue(token.supportsInterface(type(IERC721Metadata).interfaceId));
        assertTrue(token.supportsInterface(type(IERC721ItemsFunctions).interfaceId));
        assertTrue(token.supportsInterface(type(IERC721SoulboundFunctions).interfaceId));
    }

    /**
     * Test all public selectors for collisions against the proxy admin functions.
     * @dev yarn ts-node scripts/outputSelectors.ts
     */
    function testSelectorCollision() public pure {
        checkSelectorCollision(0xa217fddf); // DEFAULT_ADMIN_ROLE()
        checkSelectorCollision(0x68a37ae8); // TRANSFER_ADMIN_ROLE()
        checkSelectorCollision(0x095ea7b3); // approve(address,uint256)
        checkSelectorCollision(0x70a08231); // balanceOf(address)
        checkSelectorCollision(0xdc8e92ea); // batchBurn(uint256[])
        checkSelectorCollision(0x42966c68); // burn(uint256)
        checkSelectorCollision(0xe8a3d485); // contractURI()
        checkSelectorCollision(0xc23dc68f); // explicitOwnershipOf(uint256)
        checkSelectorCollision(0x5bbb2177); // explicitOwnershipsOf(uint256[])
        checkSelectorCollision(0x081812fc); // getApproved(uint256)
        checkSelectorCollision(0x248a9ca3); // getRoleAdmin(bytes32)
        checkSelectorCollision(0x9010d07c); // getRoleMember(bytes32,uint256)
        checkSelectorCollision(0xca15c873); // getRoleMemberCount(bytes32)
        checkSelectorCollision(0x842f9b68); // getTransferLocked()
        checkSelectorCollision(0x2f2ff15d); // grantRole(bytes32,address)
        checkSelectorCollision(0x91d14854); // hasRole(bytes32,address)
        checkSelectorCollision(0x98dd69c8); // initialize(address,string,string,string,string,address,uint96)
        checkSelectorCollision(0xe985e9c5); // isApprovedForAll(address,address)
        checkSelectorCollision(0x40c10f19); // mint(address,uint256)
        checkSelectorCollision(0x06fdde03); // name()
        checkSelectorCollision(0x6352211e); // ownerOf(uint256)
        checkSelectorCollision(0x36568abe); // renounceRole(bytes32,address)
        checkSelectorCollision(0xd547741f); // revokeRole(bytes32,address)
        checkSelectorCollision(0x2a55205a); // royaltyInfo(uint256,uint256)
        checkSelectorCollision(0x42842e0e); // safeTransferFrom(address,address,uint256)
        checkSelectorCollision(0xb88d4fde); // safeTransferFrom(address,address,uint256,bytes)
        checkSelectorCollision(0xa22cb465); // setApprovalForAll(address,bool)
        checkSelectorCollision(0x7e518ec8); // setBaseMetadataURI(string)
        checkSelectorCollision(0x938e3d7b); // setContractURI(string)
        checkSelectorCollision(0x04634d8d); // setDefaultRoyalty(address,uint96)
        checkSelectorCollision(0x5a446215); // setNameAndSymbol(string,string)
        checkSelectorCollision(0x5944c753); // setTokenRoyalty(uint256,address,uint96)
        checkSelectorCollision(0x35e60bd4); // setTransferLocked(bool)
        checkSelectorCollision(0x01ffc9a7); // supportsInterface(bytes4)
        checkSelectorCollision(0x95d89b41); // symbol()
        checkSelectorCollision(0xc87b56dd); // tokenURI(uint256)
        checkSelectorCollision(0x8462151c); // tokensOfOwner(address)
        checkSelectorCollision(0x99a2557a); // tokensOfOwnerIn(address,uint256,uint256)
        checkSelectorCollision(0x18160ddd); // totalSupply()
        checkSelectorCollision(0x23b872dd); // transferFrom(address,address,uint256)
    }

    function testOwnerHasRoles() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(token.hasRole(keccak256("TRANSFER_ADMIN_ROLE"), owner));
        assertTrue(token.hasRole(keccak256("METADATA_ADMIN_ROLE"), owner));
        assertTrue(token.hasRole(keccak256("MINTER_ROLE"), owner));
        assertTrue(token.hasRole(keccak256("ROYALTY_ADMIN_ROLE"), owner));
    }

    function testFactoryDetermineAddress(
        address _proxyOwner,
        address tokenOwner,
        string memory name,
        string memory symbol,
        string memory baseURI,
        string memory contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) public {
        vm.assume(_proxyOwner != address(0));
        vm.assume(tokenOwner != address(0));
        vm.assume(royaltyReceiver != address(0));
        royaltyFeeNumerator = uint96(bound(royaltyFeeNumerator, 0, 10_000));
        ERC721SoulboundFactory factory = new ERC721SoulboundFactory(address(this));
        address deployedAddr = factory.deploy(
            _proxyOwner, tokenOwner, name, symbol, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator
        );
        address predictedAddr = factory.determineAddress(
            _proxyOwner, tokenOwner, name, symbol, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator
        );
        assertEq(deployedAddr, predictedAddr);
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

    function testTransferLocked(address holder, address receiver) public {
        vm.assume(holder != receiver);
        assumeSafeAddress(holder);
        assumeSafeAddress(receiver);

        vm.prank(owner);
        token.mint(holder, 1);

        vm.expectRevert(TransfersLocked.selector);
        vm.prank(holder);
        token.transferFrom(holder, receiver, 0);
    }

    function testTransferLockedOperator(address holder, address operator, address receiver) public {
        vm.assume(holder != receiver);
        vm.assume(holder != operator);
        assumeSafeAddress(holder);
        assumeSafeAddress(operator);
        assumeSafeAddress(receiver);

        vm.prank(owner);
        token.mint(holder, 1);

        vm.prank(holder);
        token.setApprovalForAll(operator, true);

        vm.expectRevert(TransfersLocked.selector);
        vm.prank(operator);
        token.transferFrom(holder, receiver, 0);
    }

    function testTransferUnlocked(address holder, address receiver) public {
        vm.assume(holder != receiver);
        assumeSafeAddress(holder);
        assumeSafeAddress(receiver);

        vm.prank(owner);
        token.mint(holder, 1);

        vm.prank(owner);
        token.setTransferLocked(false);

        vm.prank(holder);
        token.transferFrom(holder, receiver, 0);

        vm.assertEq(token.ownerOf(0), receiver);
    }

    function testTransferUnlockedOperator(address holder, address operator, address receiver) public {
        vm.assume(holder != receiver);
        vm.assume(holder != operator);
        assumeSafeAddress(holder);
        assumeSafeAddress(operator);
        assumeSafeAddress(receiver);

        vm.prank(owner);
        token.mint(holder, 1);

        vm.prank(owner);
        token.setTransferLocked(false);

        vm.prank(holder);
        token.setApprovalForAll(operator, true);

        vm.prank(operator);
        token.transferFrom(holder, receiver, 0);

        vm.assertEq(token.ownerOf(0), receiver);
    }

}
