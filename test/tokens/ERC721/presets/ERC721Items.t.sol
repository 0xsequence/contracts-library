// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { TestHelper } from "../../../TestHelper.sol";

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

import { ERC721 } from "solady/tokens/ERC721.sol";
import { LibString } from "solady/utils/LibString.sol";

contract ERC721ItemsTest is TestHelper, IERC721ItemsSignals {

    // Redeclare events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    ERC721Items private token;

    address private proxyOwner;
    address private owner;

    function setUp() public {
        owner = makeAddr("owner");
        proxyOwner = makeAddr("proxyOwner");

        vm.deal(address(this), 100 ether);
        vm.deal(owner, 100 ether);

        ERC721ItemsFactory factory = new ERC721ItemsFactory(address(this));
        token = ERC721Items(
            factory.deploy(
                proxyOwner, owner, "name", "symbol", "baseURI", "contractURI", address(this), 0, address(0), bytes32(0)
            )
        );
    }

    function testReinitializeFails() public {
        vm.expectRevert(InvalidInitialization.selector);
        token.initialize(owner, "name", "symbol", "baseURI", "contractURI", address(this), 0, address(0), bytes32(0));
    }

    function testSupportsInterface() public view {
        assertTrue(token.supportsInterface(type(IERC165).interfaceId));
        assertTrue(token.supportsInterface(type(IERC721).interfaceId));
        assertTrue(token.supportsInterface(type(IERC721Metadata).interfaceId));
        assertTrue(token.supportsInterface(type(IERC721ItemsFunctions).interfaceId));
        assertTrue(token.supportsInterface(type(ISignalsImplicitMode).interfaceId));
    }

    /**
     * Test all public selectors for collisions against the proxy admin functions.
     * @dev yarn ts-node scripts/outputSelectors.ts
     */
    function testSelectorCollision() public pure {
        checkSelectorCollision(0xa217fddf); // DEFAULT_ADMIN_ROLE()
        checkSelectorCollision(0xc58ab92d); // acceptImplicitRequest(address,(address,bytes4,bytes32,bytes32,bytes,(string)),(address,uint256,bytes,uint256,bool,bool,uint256))
        checkSelectorCollision(0x095ea7b3); // approve(address,uint256)
        checkSelectorCollision(0x70a08231); // balanceOf(address)
        checkSelectorCollision(0xdc8e92ea); // batchBurn(uint256[])
        checkSelectorCollision(0x42966c68); // burn(uint256)
        checkSelectorCollision(0xe8a3d485); // contractURI()
        checkSelectorCollision(0x081812fc); // getApproved(uint256)
        checkSelectorCollision(0x248a9ca3); // getRoleAdmin(bytes32)
        checkSelectorCollision(0x9010d07c); // getRoleMember(bytes32,uint256)
        checkSelectorCollision(0xca15c873); // getRoleMemberCount(bytes32)
        checkSelectorCollision(0x2f2ff15d); // grantRole(bytes32,address)
        checkSelectorCollision(0x91d14854); // hasRole(bytes32,address)
        checkSelectorCollision(0x4c62cd9b); // initialize(address,string,string,string,string,address,uint96,address,bytes32)
        checkSelectorCollision(0xe985e9c5); // isApprovedForAll(address,address)
        checkSelectorCollision(0x40c10f19); // mint(address,uint256)
        checkSelectorCollision(0x2e73e0fd); // mintSequential(address,uint256)
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
        checkSelectorCollision(0xed4c2ac7); // setImplicitModeProjectId(bytes32)
        checkSelectorCollision(0x0bb310de); // setImplicitModeValidator(address)
        checkSelectorCollision(0x5a446215); // setNameAndSymbol(string,string)
        checkSelectorCollision(0x5944c753); // setTokenRoyalty(uint256,address,uint96)
        checkSelectorCollision(0x01ffc9a7); // supportsInterface(bytes4)
        checkSelectorCollision(0x95d89b41); // symbol()
        checkSelectorCollision(0xc87b56dd); // tokenURI(uint256)
        checkSelectorCollision(0x18160ddd); // totalSupply()
        checkSelectorCollision(0x23b872dd); // transferFrom(address,address,uint256)
    }

    function testOwnerHasRoles() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(token.hasRole(keccak256("METADATA_ADMIN_ROLE"), owner));
        assertTrue(token.hasRole(keccak256("MINTER_ROLE"), owner));
        assertTrue(token.hasRole(keccak256("ROYALTY_ADMIN_ROLE"), owner));
        assertTrue(token.hasRole(keccak256("IMPLICIT_MODE_ADMIN_ROLE"), owner));
    }

    function testFactoryDetermineAddress(
        address _proxyOwner,
        address tokenOwner,
        string memory name,
        string memory symbol,
        string memory baseURI,
        string memory contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        address implicitModeValidator,
        bytes32 implicitModeProjectId
    ) public {
        vm.assume(_proxyOwner != address(0));
        vm.assume(tokenOwner != address(0));
        vm.assume(royaltyReceiver != address(0));
        royaltyFeeNumerator = uint96(bound(royaltyFeeNumerator, 0, 10_000));
        ERC721ItemsFactory factory = new ERC721ItemsFactory(address(this));
        address deployedAddr = factory.deploy(
            _proxyOwner,
            tokenOwner,
            name,
            symbol,
            baseURI,
            contractURI,
            royaltyReceiver,
            royaltyFeeNumerator,
            implicitModeValidator,
            implicitModeProjectId
        );
        address predictedAddr = factory.determineAddress(
            _proxyOwner,
            tokenOwner,
            name,
            symbol,
            baseURI,
            contractURI,
            royaltyReceiver,
            royaltyFeeNumerator,
            implicitModeValidator,
            implicitModeProjectId
        );
        assertEq(deployedAddr, predictedAddr);
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
        vm.expectRevert(ERC721.TokenDoesNotExist.selector); // Not minted
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
        vm.assume(caller != proxyOwner);

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(caller),
                " is missing role ",
                vm.toString(keccak256("MINTER_ROLE"))
            )
        );
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
    }

    function testMintWithRole(address minter, uint256 tokenId) public {
        vm.assume(minter != owner);
        vm.assume(minter != proxyOwner);
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
        vm.expectRevert(ERC721.TokenAlreadyExists.selector);
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
        vm.expectRevert(ERC721.TokenAlreadyExists.selector);
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

        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        token.ownerOf(tokenId);
    }

    function testBurnInvalidOwnership(address caller, uint256 tokenId) public {
        assumeSafeAddress(caller);

        vm.prank(owner);
        token.mint(caller, tokenId);

        vm.expectRevert(ERC721.NotOwnerNorApproved.selector);
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

        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
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

        vm.expectRevert(ERC721.NotOwnerNorApproved.selector);
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
        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        token.tokenURI(2);
    }

    function testMetadataInvalid(
        address caller
    ) public {
        vm.assume(caller != owner);
        vm.assume(caller != proxyOwner);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(caller),
                " is missing role ",
                vm.toString(keccak256("METADATA_ADMIN_ROLE"))
            )
        );
        vm.prank(caller);
        token.setBaseMetadataURI("ipfs://newURI/");
    }

    function testMetadataWithRole(
        address caller
    ) public {
        vm.assume(caller != owner);
        vm.assume(caller != proxyOwner);
        vm.assume(caller != address(0));
        // Give role
        vm.startPrank(owner);
        token.grantRole(keccak256("METADATA_ADMIN_ROLE"), caller);
        vm.stopPrank();

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
        vm.assume(caller != proxyOwner);
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
        vm.assume(caller != proxyOwner);
        vm.assume(salePrice < type(uint128).max); // Buffer for overflow

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(caller),
                " is missing role ",
                vm.toString(keccak256("ROYALTY_ADMIN_ROLE"))
            )
        );
        vm.prank(caller);
        token.setDefaultRoyalty(receiver, feeNumerator);

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(caller),
                " is missing role ",
                vm.toString(keccak256("ROYALTY_ADMIN_ROLE"))
            )
        );
        vm.prank(caller);
        token.setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

}
