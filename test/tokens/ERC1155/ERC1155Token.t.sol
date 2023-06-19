// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {ERC1155Token, InvalidInitialization} from "src/tokens/ERC1155/ERC1155Token.sol";
import {ERC1155TokenFactory} from "src/tokens/ERC1155/ERC1155TokenFactory.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// Interfaces
import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {IERC1155Metadata} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155Metadata.sol";

contract ERC1155TokenTest is Test {
    // Redeclare events
    event TransferSingle(
        address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _amount
    );
    event TransferBatch(
        address indexed _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _amounts
    );

    ERC1155Token private token;

    address owner;

    function setUp() public {
        owner = makeAddr("owner");

        vm.deal(address(this), 100 ether);
        vm.deal(owner, 100 ether);

        ERC1155TokenFactory factory = new ERC1155TokenFactory();
        token = ERC1155Token(factory.deploy(owner, "name", "baseURI", 0x0));
    }

    function testReinitializeFails() public {
        vm.expectRevert(InvalidInitialization.selector);
        token.initialize(owner, "name", "baseURI");
    }

    function testSupportsInterface() public {
        assertTrue(token.supportsInterface(type(IERC165).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155Metadata).interfaceId));
    }

    function testOwnerHasRoles() public {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(token.hasRole(token.METADATA_ADMIN_ROLE(), owner));
        assertTrue(token.hasRole(token.MINTER_ROLE(), owner));
        assertTrue(token.hasRole(token.ROYALTY_ADMIN_ROLE(), owner));
    }

    //
    // Minting
    //
    function testMintInvalidRole(address caller) public {
        vm.assume(caller != owner);

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(caller),
                " is missing role ",
                Strings.toHexString(uint256(token.MINTER_ROLE()), 32)
            )
        );
        vm.prank(caller);
        token.mint(caller, 1, 1, "");

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(caller),
                " is missing role ",
                Strings.toHexString(uint256(token.MINTER_ROLE()), 32)
            )
        );
        vm.prank(caller);
        token.batchMint(caller, tokenIds, amounts, "");
    }

    function testMintOwner(uint256 tokenId, uint256 amount) public {
        vm.assume(amount > 0);

        vm.expectEmit(true, true, true, true, address(token));
        emit TransferSingle(owner, address(0), owner, tokenId, amount);
        vm.prank(owner);
        token.mint(owner, tokenId, amount, "");

        assertEq(token.balanceOf(owner, tokenId), amount);
    }

    function testBatchMintOwner(uint256[] memory tokenIds, uint256[] memory amounts) public {
        tokenIds = boundArrayLength(tokenIds, 10);
        amounts = boundArrayLength(amounts, 10);
        vm.assume(tokenIds.length == amounts.length);
        for (uint256 i; i < amounts.length; i++) {
            vm.assume(amounts[i] > 0);
        }
        // Unique ids
        for (uint256 i; i < tokenIds.length; i++) {
            for (uint256 j; j < tokenIds.length; j++) {
                if (i != j) {
                    vm.assume(tokenIds[i] != tokenIds[j]);
                }
            }
        }

        vm.expectEmit(true, true, true, true, address(token));
        emit TransferBatch(owner, address(0), owner, tokenIds, amounts);
        vm.prank(owner);
        token.batchMint(owner, tokenIds, amounts, "");
    }

    function testMintWithRole(address minter, uint256 tokenId, uint256 amount) public {
        vm.assume(minter != owner);
        vm.assume(minter != address(0));
        // Give role
        vm.startPrank(owner);
        token.grantRole(token.MINTER_ROLE(), minter);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true, address(token));
        emit TransferSingle(minter, address(0), owner, tokenId, amount);

        vm.prank(minter);
        token.mint(owner, tokenId, amount, "");

        assertEq(token.balanceOf(owner, tokenId), amount);
    }

    function testBatchMintWithRole(address minter, uint256[] memory tokenIds, uint256[] memory amounts) public {
        vm.assume(minter != owner);
        vm.assume(minter != address(0));
        tokenIds = boundArrayLength(tokenIds, 10);
        amounts = boundArrayLength(amounts, 10);
        vm.assume(tokenIds.length == amounts.length);
        for (uint256 i; i < amounts.length; i++) {
            vm.assume(amounts[i] > 0);
        }
        // Unique ids
        for (uint256 i; i < tokenIds.length; i++) {
            for (uint256 j; j < tokenIds.length; j++) {
                if (i != j) {
                    vm.assume(tokenIds[i] != tokenIds[j]);
                }
            }
        }

        // Give role
        vm.startPrank(owner);
        token.grantRole(token.MINTER_ROLE(), minter);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true, address(token));
        emit TransferBatch(minter, address(0), owner, tokenIds, amounts);
        vm.prank(minter);
        token.batchMint(owner, tokenIds, amounts, "");
    }

    //
    // Metadata
    //
    function testMetadataOwner() public {
        vm.prank(owner);
        token.setBaseMetadataURI("ipfs://newURI/");

        assertEq(token.uri(0), "ipfs://newURI/0.json");
        assertEq(token.uri(1), "ipfs://newURI/1.json");
    }

    function testMetadataInvalid(address caller) public {
        vm.assume(caller != owner);
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
        assertEq(receiver_, address(0));
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

    function boundArrayLength(uint256[] memory arr, uint256 maxSize) private pure returns (uint256[] memory) {
        if (arr.length <= maxSize) {
            return arr;
        }
        uint256[] memory result = new uint256[](maxSize);
        for (uint256 i; i < maxSize; i++) {
            result[i] = arr[i];
        }
        return result;
    }
}
