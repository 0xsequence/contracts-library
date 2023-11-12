// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {ERC721TokenMinter} from "src/tokens/ERC721/presets/minter/ERC721TokenMinter.sol";
import {IERC721TokenMinterSignals} from "src/tokens/ERC721/presets/minter/IERC721TokenMinter.sol";
import {ERC721TokenMinterFactory} from "src/tokens/ERC721/presets/minter/ERC721TokenMinterFactory.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// Interfaces
import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC721A} from "erc721a/contracts/interfaces/IERC721A.sol";
import {IERC721AQueryable} from "erc721a/contracts/extensions/IERC721AQueryable.sol";

contract ERC721TokenMinterTest is Test, IERC721TokenMinterSignals {
    // Redeclare events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    ERC721TokenMinter private token;

    address private proxyOwner;
    address private owner;

    function setUp() public {
        owner = makeAddr("owner");
        proxyOwner = makeAddr("proxyOwner");

        vm.deal(address(this), 100 ether);
        vm.deal(owner, 100 ether);

        ERC721TokenMinterFactory factory = new ERC721TokenMinterFactory(address(this));
        token = ERC721TokenMinter(factory.deploy(proxyOwner, owner, "name", "symbol", "baseURI", address(this), 0));
    }

    function testReinitializeFails() public {
        vm.expectRevert(InvalidInitialization.selector);
        token.initialize(owner, "name", "symbol", "baseURI", address(this), 0);
    }

    function testSupportsInterface() public {
        assertTrue(token.supportsInterface(type(IERC165).interfaceId));
        assertTrue(token.supportsInterface(type(IERC721A).interfaceId));
        assertTrue(token.supportsInterface(type(IERC721AQueryable).interfaceId));
        assertTrue(token.supportsInterface(0x80ac58cd)); // ERC721
        assertTrue(token.supportsInterface(0x5b5e139f)); // ERC721Metadata
    }

    function testOwnerHasRoles() public {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(token.hasRole(token.METADATA_ADMIN_ROLE(), owner));
        assertTrue(token.hasRole(token.MINTER_ROLE(), owner));
        assertTrue(token.hasRole(token.ROYALTY_ADMIN_ROLE(), owner));
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
                Strings.toHexString(uint256(token.MINTER_ROLE()), 32)
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
        token.grantRole(token.MINTER_ROLE(), minter);
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
                Strings.toHexString(uint256(token.METADATA_ADMIN_ROLE()), 32)
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
        token.grantRole(token.METADATA_ADMIN_ROLE(), caller);
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
    )
        public
    {
        vm.assume(feeNumerator <= 10000);
        vm.assume(receiver != address(0));
        vm.assume(caller != owner);
        vm.assume(caller != proxyOwner);
        vm.assume(salePrice < type(uint128).max); // Buffer for overflow

        vm.startPrank(owner);
        token.grantRole(token.ROYALTY_ADMIN_ROLE(), caller);
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
    )
        public
    {
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
                Strings.toHexString(uint256(token.ROYALTY_ADMIN_ROLE()), 32)
            )
        );
        vm.prank(caller);
        token.setDefaultRoyalty(receiver, feeNumerator);

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(caller),
                " is missing role ",
                Strings.toHexString(uint256(token.ROYALTY_ADMIN_ROLE()), 32)
            )
        );
        vm.prank(caller);
        token.setTokenRoyalty(tokenId, receiver, feeNumerator);
    }
}
