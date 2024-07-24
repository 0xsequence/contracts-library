// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {TestHelper} from "../../../TestHelper.sol";

import {ERC721Items} from "src/tokens/ERC721/presets/items/ERC721Items.sol";
import {
    IERC721ItemsSignals, IERC721ItemsFunctions, IERC721Items
} from "src/tokens/ERC721/presets/items/IERC721Items.sol";
import {ERC721ItemsFactory} from "src/tokens/ERC721/presets/items/ERC721ItemsFactory.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// Interfaces
import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC721A} from "erc721a/contracts/interfaces/IERC721A.sol";
import {IERC721AQueryable} from "erc721a/contracts/extensions/IERC721AQueryable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";

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
        token =
            ERC721Items(factory.deploy(proxyOwner, owner, "name", "symbol", "baseURI", "contractURI", address(this), 0));
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
    }

    /**
     * Test all public selectors for collisions against the proxy admin functions.
     * @dev yarn ts-node scripts/outputSelectors.ts
     */
    function testSelectorCollision() public pure {
        checkSelectorCollision(0xa217fddf); // DEFAULT_ADMIN_ROLE()
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
        ERC721ItemsFactory factory = new ERC721ItemsFactory(address(this));
        address deployedAddr = factory.deploy(
            _proxyOwner, tokenOwner, name, symbol, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator
        );
        address predictedAddr = factory.determineAddress(
            _proxyOwner, tokenOwner, name, symbol, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator
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

    function testTokenMetadata() external {
        address nonOwner = makeAddr("nonOwner");
        vm.expectRevert(); // Missing role
        vm.prank(nonOwner);
        token.setBaseMetadataURI("metadata://");

        vm.prank(owner);
        token.setBaseMetadataURI("metadata://");
        vm.expectRevert(IERC721A.URIQueryForNonexistentToken.selector); // Not minted
        token.tokenURI(0);

        testMintOwner();
        assertEq("metadata://0", token.tokenURI(0));
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
    function testMintInvalidRole(address caller) public {
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
        token.mint(caller, 1);
    }

    function testMintOwner() public {
        vm.expectEmit(true, true, true, true, address(token));
        emit Transfer(address(0), owner, 0);

        vm.prank(owner);
        token.mint(owner, 1);

        assertEq(token.balanceOf(owner), 1);
    }

    function testMintWithRole(address minter) public {
        vm.assume(minter != owner);
        vm.assume(minter != proxyOwner);
        vm.assume(minter != address(0));
        // Give role
        vm.startPrank(owner);
        token.grantRole(keccak256("MINTER_ROLE"), minter);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true, address(token));
        emit Transfer(address(0), owner, 0);

        vm.prank(minter);
        token.mint(owner, 1);

        assertEq(token.balanceOf(owner), 1);
    }

    function testMintMultiple() public {
        vm.expectEmit(true, true, true, true, address(token));
        emit Transfer(address(0), owner, 0);
        vm.expectEmit(true, true, true, true, address(token));
        emit Transfer(address(0), owner, 1);

        vm.prank(owner);
        token.mint(owner, 2);

        assertEq(token.balanceOf(owner), 2);
        assertEq(token.ownerOf(0), owner);
        assertEq(token.ownerOf(1), owner);
    }

    //
    // Burn
    //
    function testBurnSuccess(address caller) public {
        assumeSafeAddress(caller);

        vm.prank(owner);
        token.mint(caller, 1);

        vm.expectEmit(true, true, true, false, address(token));
        emit Transfer(caller, address(0), 0);

        vm.prank(caller);
        token.burn(0);

        vm.expectRevert(IERC721A.OwnerQueryForNonexistentToken.selector);
        token.ownerOf(0);
    }

    function testBurnInvalidOwnership(address caller) public {
        assumeSafeAddress(caller);

        vm.prank(owner);
        token.mint(caller, 1);

        vm.expectRevert(IERC721A.TransferCallerNotOwnerNorApproved.selector);
        token.burn(0);
    }

    function testBurnBatchSuccess(address caller) public {
        assumeSafeAddress(caller);

        vm.prank(owner);
        token.mint(caller, 2);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;

        vm.expectEmit(true, true, true, false, address(token));
        emit Transfer(caller, address(0), 0);
        vm.expectEmit(true, true, true, false, address(token));
        emit Transfer(caller, address(0), 1);

        vm.prank(caller);
        token.batchBurn(ids);

        vm.expectRevert(IERC721A.OwnerQueryForNonexistentToken.selector);
        token.ownerOf(0);
    }

    function testBurnBatchInvalidOwnership(address caller) public {
        assumeSafeAddress(caller);

        vm.prank(owner);
        token.mint(caller, 2);

        uint256[] memory ids = new uint256[](2);
        ids[0] = 0;
        ids[1] = 1;

        vm.expectRevert(IERC721A.TransferCallerNotOwnerNorApproved.selector);
        token.batchBurn(ids);
    }

    //
    // Metadata
    //
    function testMetadataOwner() public {
        // Mint token
        vm.prank(owner);
        token.mint(owner, 2);

        vm.prank(owner);
        token.setBaseMetadataURI("ipfs://newURI/");

        assertEq(token.tokenURI(0), "ipfs://newURI/0");
        assertEq(token.tokenURI(1), "ipfs://newURI/1");

        // Invalid token
        vm.expectRevert(IERC721A.URIQueryForNonexistentToken.selector);
        token.tokenURI(2);
    }

    function testMetadataInvalid(address caller) public {
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

    function testMetadataWithRole(address caller) public {
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
