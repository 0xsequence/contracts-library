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
import { IOwnable } from "src/modular/modules/ownable/IOwnable.sol";
import { ERC721ItemsExtension } from "src/modular/modules/tokens/erc721/items/ERC721ItemsExtension.sol";
import { ERC2981Controlled } from "src/modular/modules/tokens/royalty/ERC2981Controlled.sol";
import { ERC721Items } from "src/tokens/ERC721/presets/items/ERC721Items.sol";
import { ERC721ItemsFactory } from "src/tokens/ERC721/presets/items/ERC721ItemsFactory.sol";
import {
    IERC721Items, IERC721ItemsFunctions, IERC721ItemsSignals
} from "src/tokens/ERC721/presets/items/IERC721Items.sol";

import { IERC721 } from "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import { IERC721Metadata } from "openzeppelin-contracts/contracts/interfaces/IERC721Metadata.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";
import { IERC165 } from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

import { ISignalsImplicitMode } from "signals-implicit-mode/src/helper/SignalsImplicitMode.sol";

import { ERC721 as SoladyERC721 } from "solady/tokens/ERC721.sol";
import { LibString } from "solady/utils/LibString.sol";

contract ERC721ItemsTest is TestHelper, IERC721ItemsSignals {

    // Redeclare events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    ERC721Items public token;
    address public owner;

    function setUp() public {
        owner = makeAddr("owner");

        ERC721 erc721Impl = new ERC721();
        ModularProxyFactory factory = new ModularProxyFactory();
        ModularProxy proxy = factory.deploy(0, address(erc721Impl), owner);
        address this_ = address(this);
        // Add each extension to match original ERC721Items functions
        vm.startPrank(owner);
        proxy.attachModule(new AccessControl(), abi.encodePacked(owner));
        proxy.attachModule(new ERC721ItemsExtension(), abi.encodePacked(owner, owner));
        proxy.attachModule(new ERC2981Controlled(), abi.encodePacked(owner, this_, uint96(0)));
        proxy.attachModule(new SignalsImplicitModeControlled(), abi.encodePacked(owner));
        vm.stopPrank();
        token = ERC721Items(address(proxy));
    }

    function testSupportsInterface() public view {
        assertTrue(token.supportsInterface(type(IERC165).interfaceId), "IERC165");
        assertTrue(token.supportsInterface(type(IERC721).interfaceId), "IERC721");
        assertTrue(token.supportsInterface(type(IERC721Metadata).interfaceId), "IERC721Metadata");
        assertTrue(token.supportsInterface(type(IERC721ItemsFunctions).interfaceId), "IERC721ItemsFunctions");
        assertTrue(token.supportsInterface(type(ISignalsImplicitMode).interfaceId), "ISignalsImplicitMode");
        assertTrue(
            token.supportsInterface(type(ISignalsImplicitModeControlled).interfaceId), "ISignalsImplicitModeControlled"
        );
    }

    function testOwnerHasRoles() public view {
        assertTrue(token.hasRole(bytes32(0), owner));
        // assertTrue(token.hasRole(keccak256("METADATA_ADMIN_ROLE"), owner));
        assertTrue(token.hasRole(keccak256("MINTER_ROLE"), owner));
        // assertTrue(token.hasRole(keccak256("ROYALTY_ADMIN_ROLE"), owner));
        assertTrue(token.hasRole(keccak256("IMPLICIT_MODE_ADMIN_ROLE"), owner));
    }

    //
    // Metadata
    //
    function testNameAndSymbol() external {
        address nonOwner = makeAddr("nonOwner");
        vm.expectRevert(); // Missing role
        vm.prank(nonOwner);
        token.setNameAndSymbol("name", "symbol");

        vm.prank(owner);
        token.setNameAndSymbol("name", "symbol");
        assertEq("name", token.name());
        assertEq("symbol", token.symbol());
    }

    function testTokenMetadata(
        uint256 tokenId
    ) external {
        address nonOwner = makeAddr("nonOwner");
        vm.expectRevert(); // Missing role
        vm.prank(nonOwner);
        token.setBaseMetadataURI("metadata://");

        vm.prank(owner);
        token.setBaseMetadataURI("metadata://");
        vm.expectRevert(SoladyERC721.TokenDoesNotExist.selector); // Not minted
        token.tokenURI(tokenId);

        testMintOwner(tokenId);
        assertEq(LibString.concat("metadata://", vm.toString(tokenId)), token.tokenURI(tokenId));
    }

    function testContractURI() external {
        address nonOwner = makeAddr("nonOwner");
        vm.expectRevert(); // Missing role
        vm.prank(nonOwner);
        token.setContractURI("contract://");

        vm.prank(owner);
        token.setContractURI("contract://");
        assertEq("contract://", token.contractURI());
    }

    //
    // Minting
    //
    function testMintInvalidRole(address caller, uint256 tokenId) public {
        vm.assume(caller != owner);

        vm.expectRevert(abi.encodeWithSelector(IAccessControl.NoRole.selector, caller, keccak256("MINTER_ROLE")));
        vm.prank(caller);
        token.mint(caller, tokenId);
    }

    function testMintOwner(
        uint256 tokenId
    ) public {
        vm.expectEmit(true, true, true, true, address(token));
        emit Transfer(address(0), owner, tokenId);

        vm.prank(owner);
        token.mint(owner, tokenId);

        assertEq(token.balanceOf(owner), 1);
        assertEq(token.ownerOf(tokenId), owner);
    }

    function testMintWithRole(address minter, uint256 tokenId) public {
        vm.assume(minter != owner);
        vm.assume(minter != address(0));
        // Give role
        vm.startPrank(owner);
        token.grantRole(keccak256("MINTER_ROLE"), minter);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true, address(token));
        emit Transfer(address(0), owner, tokenId);

        vm.prank(minter);
        token.mint(owner, tokenId);

        assertEq(token.balanceOf(owner), 1);
    }

    function testMintMultiple() public {
        vm.expectEmit(true, true, true, true, address(token));
        emit Transfer(address(0), owner, 0);
        vm.expectEmit(true, true, true, true, address(token));
        emit Transfer(address(0), owner, 1);

        vm.prank(owner);
        token.mintSequential(owner, 2);

        assertEq(token.balanceOf(owner), 2);
        assertEq(token.ownerOf(0), owner);
        assertEq(token.ownerOf(1), owner);
    }

    function testMintCollision(
        uint256 tokenId
    ) public {
        vm.prank(owner);
        token.mint(owner, tokenId);
        assertEq(token.ownerOf(tokenId), owner);

        // Try to mint the same token again
        vm.expectRevert(SoladyERC721.TokenAlreadyExists.selector);
        vm.prank(owner);
        token.mint(owner, tokenId);
    }

    function testMintCollisionOverSequentialMint(uint256 amount, uint256 tokenId) public {
        amount = bound(amount, 1, 10);
        tokenId = bound(tokenId, 0, amount - 1);

        // Spot mint
        vm.prank(owner);
        token.mintSequential(owner, amount);
        assertEq(token.ownerOf(tokenId), owner);

        // Try to mint the same token again
        vm.expectRevert(SoladyERC721.TokenAlreadyExists.selector);
        vm.prank(owner);
        token.mint(owner, tokenId);
    }

    function testSequentialMintOverSpotMint(uint256 amount, uint256 spotTokenId) public {
        amount = bound(amount, 1, 10);
        spotTokenId = bound(spotTokenId, 0, amount - 1);

        // Spot mint
        vm.prank(owner);
        token.mint(owner, spotTokenId);
        assertEq(token.ownerOf(spotTokenId), owner);

        // Now do sequential minting
        vm.prank(owner);
        token.mintSequential(owner, amount);

        // owner should have amount + 1 tokens
        assertEq(token.balanceOf(owner), amount + 1);
    }

    function testTotalSupply(uint256 amount, uint256[] memory spotTokenIds) public {
        amount = bound(amount, 1, 10);
        if (spotTokenIds.length > 10) {
            // Max 10 spot minted
            assembly {
                mstore(spotTokenIds, 10)
            }
        }
        // Ensure no duplicates
        for (uint256 i = 0; i < spotTokenIds.length; i++) {
            for (uint256 j = i + 1; j < spotTokenIds.length; j++) {
                vm.assume(spotTokenIds[i] != spotTokenIds[j]);
            }
        }

        vm.startPrank(owner);
        for (uint256 i = 0; i < spotTokenIds.length; i++) {
            token.mint(owner, spotTokenIds[i]);
        }
        token.mintSequential(owner, amount);
        vm.stopPrank();

        assertEq(token.balanceOf(owner), amount + spotTokenIds.length);
        assertEq(token.totalSupply(), amount + spotTokenIds.length);
    }

    //
    // Burn
    //
    function testBurnSuccess(address caller, uint256 tokenId) public {
        assumeSafeAddress(caller);

        vm.prank(owner);
        token.mint(caller, tokenId);

        vm.expectEmit(true, true, true, false, address(token));
        emit Transfer(caller, address(0), tokenId);

        vm.prank(caller);
        token.burn(tokenId);

        vm.expectRevert(SoladyERC721.TokenDoesNotExist.selector);
        token.ownerOf(tokenId);
    }

    function testBurnInvalidOwnership(address caller, uint256 tokenId) public {
        assumeSafeAddress(caller);

        vm.prank(owner);
        token.mint(caller, tokenId);

        vm.expectRevert(SoladyERC721.NotOwnerNorApproved.selector);
        token.burn(tokenId);
    }

    function testBurnBatchSuccess(
        address caller
    ) public {
        assumeSafeAddress(caller);

        vm.prank(owner);
        token.mintSequential(caller, 2);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;

        vm.expectEmit(true, true, true, false, address(token));
        emit Transfer(caller, address(0), 0);
        vm.expectEmit(true, true, true, false, address(token));
        emit Transfer(caller, address(0), 1);

        vm.prank(caller);
        token.batchBurn(ids);

        vm.expectRevert(SoladyERC721.TokenDoesNotExist.selector);
        token.ownerOf(0);
    }

    function testBurnBatchInvalidOwnership(
        address caller
    ) public {
        assumeSafeAddress(caller);

        vm.prank(owner);
        token.mintSequential(caller, 2);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;

        vm.expectRevert(SoladyERC721.NotOwnerNorApproved.selector);
        token.batchBurn(ids);
    }

    //
    // Metadata
    //
    function testMetadataOwner() public {
        // Mint token
        vm.prank(owner);
        token.mintSequential(owner, 2);

        vm.prank(owner);
        token.setBaseMetadataURI("ipfs://newURI/");

        assertEq(token.tokenURI(0), "ipfs://newURI/0");
        assertEq(token.tokenURI(1), "ipfs://newURI/1");

        // Invalid token
        vm.expectRevert(SoladyERC721.TokenDoesNotExist.selector);
        token.tokenURI(2);
    }

    function testMetadataInvalid(
        address caller
    ) public {
        vm.assume(caller != owner);
        vm.expectRevert(IOwnable.CallerIsNotOwner.selector);
        vm.prank(caller);
        token.setBaseMetadataURI("ipfs://newURI/");
    }

    //
    // Royalty
    //
    function testDefaultRoyalty(address receiver, uint96 feeNumerator, uint256 salePrice) public {
        vm.assume(feeNumerator <= 10000);
        vm.assume(receiver != address(0));
        vm.assume(salePrice < type(uint128).max); // Buffer for overflow

        vm.prank(owner);
        token.setDefaultRoyalty(receiver, feeNumerator);

        (address receiver_, uint256 amount) = token.royaltyInfo(1, salePrice);
        assertEq(receiver_, receiver);
        assertEq(amount, salePrice * feeNumerator / 10000);
    }

    function testTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator, uint256 salePrice) public {
        vm.assume(feeNumerator <= 10000);
        vm.assume(receiver != address(0));
        vm.assume(tokenId != 69); // Other token id for default validation
        vm.assume(salePrice < type(uint128).max); // Buffer for overflow

        vm.prank(owner);
        token.setTokenRoyalty(tokenId, receiver, feeNumerator);

        (address receiver_, uint256 amount) = token.royaltyInfo(tokenId, salePrice);
        assertEq(receiver_, receiver);
        assertEq(amount, salePrice * feeNumerator / 10000);

        (receiver_, amount) = token.royaltyInfo(69, salePrice);
        assertEq(receiver_, address(this));
        assertEq(amount, 0);
    }

    function testRoyaltyWithRole(
        address caller,
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator,
        uint256 salePrice
    ) public {
        vm.assume(feeNumerator <= 10000);
        vm.assume(receiver != address(0));
        vm.assume(caller != owner);
        vm.assume(salePrice < type(uint128).max); // Buffer for overflow

        vm.startPrank(owner);
        token.grantRole(keccak256("ROYALTY_ADMIN_ROLE"), caller);
        vm.stopPrank();

        vm.prank(caller);
        token.setDefaultRoyalty(receiver, feeNumerator);

        (address receiver_, uint256 amount) = token.royaltyInfo(1, salePrice);
        assertEq(receiver_, receiver);
        assertEq(amount, salePrice * feeNumerator / 10000);

        vm.prank(caller);
        token.setTokenRoyalty(tokenId, receiver, feeNumerator);

        (receiver_, amount) = token.royaltyInfo(tokenId, salePrice);
        assertEq(receiver_, receiver);
        assertEq(amount, salePrice * feeNumerator / 10000);
    }

    function testRoyaltyInvalidRole(
        address caller,
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator,
        uint256 salePrice
    ) public {
        vm.assume(feeNumerator <= 10000);
        vm.assume(receiver != address(0));
        vm.assume(caller != owner);
        vm.assume(salePrice < type(uint128).max); // Buffer for overflow

        vm.expectRevert(abi.encodeWithSelector(IAccessControl.NoRole.selector, caller, keccak256("ROYALTY_ADMIN_ROLE")));
        vm.prank(caller);
        token.setDefaultRoyalty(receiver, feeNumerator);

        vm.expectRevert(abi.encodeWithSelector(IAccessControl.NoRole.selector, caller, keccak256("ROYALTY_ADMIN_ROLE")));
        vm.prank(caller);
        token.setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

}
