// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {TestHelper} from "../../../TestHelper.sol";

import {ERC1155Soulbound} from "src/tokens/ERC1155/presets/soulbound/ERC1155Soulbound.sol";
import {IERC1155ItemsSignals, IERC1155ItemsFunctions} from "src/tokens/ERC1155/presets/items/IERC1155Items.sol";
import {
    IERC1155SoulboundSignals,
    IERC1155SoulboundFunctions,
    IERC1155Soulbound
} from "src/tokens/ERC1155/presets/soulbound/IERC1155Soulbound.sol";
import {ERC1155SoulboundFactory} from "src/tokens/ERC1155/presets/soulbound/ERC1155SoulboundFactory.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// Interfaces
import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract ERC1155SoulboundTest is TestHelper, IERC1155ItemsSignals, IERC1155SoulboundSignals {
    // Redeclare events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    ERC1155Soulbound private token;

    address private proxyOwner;
    address private owner;

    function setUp() public {
        owner = makeAddr("owner");
        proxyOwner = makeAddr("proxyOwner");

        vm.deal(address(this), 100 ether);
        vm.deal(owner, 100 ether);

        ERC1155SoulboundFactory factory = new ERC1155SoulboundFactory(address(this));
        token = ERC1155Soulbound(
            factory.deploy(proxyOwner, owner, "name", "baseURI", "contractURI", address(this), 0)
        );
    }

    function testReinitializeFails() public {
        vm.expectRevert(InvalidInitialization.selector);
        token.initialize(owner, "name", "baseURI", "contractURI", address(this), 0);
    }

    function testSupportsInterface() public view {
        assertTrue(token.supportsInterface(type(IERC165).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155ItemsFunctions).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155SoulboundFunctions).interfaceId));
    }

    /**
     * Test all public selectors for collisions against the proxy admin functions.
     * @dev yarn ts-node scripts/outputSelectors.ts
     */
    function testSelectorCollision() public pure {
        checkSelectorCollision(0xa217fddf); // DEFAULT_ADMIN_ROLE()
        checkSelectorCollision(0x68a37ae8); // TRANSFER_ADMIN_ROLE()
        checkSelectorCollision(0x00fdd58e); // balanceOf(address,uint256)
        checkSelectorCollision(0x4e1273f4); // balanceOfBatch(address[],uint256[])
        checkSelectorCollision(0x6c0360eb); // baseURI()
        checkSelectorCollision(0x20ec271b); // batchBurn(uint256[],uint256[])
        checkSelectorCollision(0xb48ab8b6); // batchMint(address,uint256[],uint256[],bytes)
        checkSelectorCollision(0xb390c0ab); // burn(uint256,uint256)
        checkSelectorCollision(0xe8a3d485); // contractURI()
        checkSelectorCollision(0x248a9ca3); // getRoleAdmin(bytes32)
        checkSelectorCollision(0x9010d07c); // getRoleMember(bytes32,uint256)
        checkSelectorCollision(0xca15c873); // getRoleMemberCount(bytes32)
        checkSelectorCollision(0x842f9b68); // getTransferLocked()
        checkSelectorCollision(0x2f2ff15d); // grantRole(bytes32,address)
        checkSelectorCollision(0x91d14854); // hasRole(bytes32,address)
        checkSelectorCollision(0xf8954818); // initialize(address,string,string,string,address,uint96)
        checkSelectorCollision(0xe985e9c5); // isApprovedForAll(address,address)
        checkSelectorCollision(0x731133e9); // mint(address,uint256,uint256,bytes)
        checkSelectorCollision(0x06fdde03); // name()
        checkSelectorCollision(0x36568abe); // renounceRole(bytes32,address)
        checkSelectorCollision(0xd547741f); // revokeRole(bytes32,address)
        checkSelectorCollision(0x2a55205a); // royaltyInfo(uint256,uint256)
        checkSelectorCollision(0x2eb2c2d6); // safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)
        checkSelectorCollision(0xf242432a); // safeTransferFrom(address,address,uint256,uint256,bytes)
        checkSelectorCollision(0xa22cb465); // setApprovalForAll(address,bool)
        checkSelectorCollision(0x7e518ec8); // setBaseMetadataURI(string)
        checkSelectorCollision(0x0b5ee006); // setContractName(string)
        checkSelectorCollision(0x938e3d7b); // setContractURI(string)
        checkSelectorCollision(0x04634d8d); // setDefaultRoyalty(address,uint96)
        checkSelectorCollision(0x5944c753); // setTokenRoyalty(uint256,address,uint96)
        checkSelectorCollision(0x35e60bd4); // setTransferLocked(bool)
        checkSelectorCollision(0x01ffc9a7); // supportsInterface(bytes4)
        checkSelectorCollision(0x2693ebf2); // tokenSupply(uint256)
        checkSelectorCollision(0x18160ddd); // totalSupply()
        checkSelectorCollision(0x0e89341c); // uri(uint256)
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
        ERC1155SoulboundFactory factory = new ERC1155SoulboundFactory(address(this));
        address deployedAddr = factory.deploy(
            _proxyOwner, tokenOwner, name, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator
        );
        address predictedAddr = factory.determineAddress(
            _proxyOwner, tokenOwner, name, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator
        );
        assertEq(deployedAddr, predictedAddr);
    }

    //
    // Transfers
    //
    function testUnlockInvalidRole(address invalid) public {
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
        token.mint(holder, tokenId, 1, "");

        vm.expectRevert(TransfersLocked.selector);
        vm.prank(holder);
        token.safeTransferFrom(holder, receiver, tokenId, 1, "");
    }

    function testTransferLockedOperator(address holder, address operator, address receiver, uint256 tokenId) public {
        vm.assume(holder != receiver);
        vm.assume(holder != operator);
        assumeSafeAddress(holder);
        assumeSafeAddress(operator);
        assumeSafeAddress(receiver);

        vm.prank(owner);
        token.mint(holder, tokenId, 1, "");

        vm.prank(holder);
        token.setApprovalForAll(operator, true);

        vm.expectRevert(TransfersLocked.selector);
        vm.prank(operator);
        token.safeTransferFrom(holder, receiver, tokenId, 1, "");
    }

    function testTransferUnlocked(address holder, address receiver, uint256 tokenId) public {
        vm.assume(holder != receiver);
        assumeSafeAddress(holder);
        assumeSafeAddress(receiver);

        vm.prank(owner);
        token.mint(holder, tokenId, 1, "");

        vm.prank(owner);
        token.setTransferLocked(false);

        vm.prank(holder);
        token.safeTransferFrom(holder, receiver, tokenId, 1, "");

        vm.assertEq(token.balanceOf(receiver, tokenId), 1);
    }

    function testTransferUnlockedOperator(address holder, address operator, address receiver, uint256 tokenId) public {
        vm.assume(holder != receiver);
        vm.assume(holder != operator);
        assumeSafeAddress(holder);
        assumeSafeAddress(operator);
        assumeSafeAddress(receiver);

        vm.prank(owner);
        token.mint(holder, tokenId, 1, "");

        vm.prank(owner);
        token.setTransferLocked(false);

        vm.prank(holder);
        token.setApprovalForAll(operator, true);

        vm.prank(operator);
        token.safeTransferFrom(holder, receiver, tokenId, 1, "");

        vm.assertEq(token.balanceOf(receiver, tokenId), 1);
    }

    function testBatchMintAllowed(address holder, uint256 tokenId) public {
        assumeSafeAddress(holder);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        vm.prank(owner);
        token.batchMint(holder, tokenIds, amounts, "");

        vm.assertEq(token.balanceOf(holder, tokenId), 1);
    }

    function testBurnBlocked(uint256 tokenId, uint256 amount) public {
        vm.expectRevert(TransfersLocked.selector);
        token.burn(tokenId, amount);
    }

    function testBatchBurnBlocked(uint256[] calldata tokenIds, uint256[] calldata amounts) public {
        vm.expectRevert(TransfersLocked.selector);
        token.batchBurn(tokenIds, amounts);
    }
}
