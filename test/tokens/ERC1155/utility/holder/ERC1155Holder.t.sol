// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { TestHelper } from "test/TestHelper.sol";
import { ERC1155Recipient } from "test/_mocks/ERC1155Recipient.sol";

import { ERC1155Items } from "src/tokens/ERC1155/presets/items/ERC1155Items.sol";
import { ERC1155Holder } from "src/tokens/ERC1155/utility/holder/ERC1155Holder.sol";

import { IERC1155Receiver } from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";
import { IERC165 } from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

import { ERC1155 } from "solady/tokens/ERC1155.sol";

contract ERC1155HolderTest is TestHelper {

    // Redeclare events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event ClaimAdded(address claimant, address tokenAddress, uint256 tokenId, uint256 amount);
    event ClaimAddedBatch(address claimant, address tokenAddress, uint256[] tokenIds, uint256[] amounts);
    event Claimed(address claimant, address tokenAddress, uint256 tokenId, uint256 amount);
    event ClaimedBatch(address claimant, address tokenAddress, uint256[] tokenIds, uint256[] amounts);

    ERC1155Items private _token;
    ERC1155Items private _token2;
    ERC1155Holder private _holder;
    ERC1155Recipient private _recipient;

    function setUp() public {
        vm.deal(address(this), 100 ether);

        _token = new ERC1155Items();
        _token.initialize(address(this), "test", "ipfs://", "ipfs://", address(this), 0, address(0), bytes32(0));

        _token2 = new ERC1155Items();
        _token2.initialize(address(this), "test2", "ipfs://", "ipfs://", address(this), 0, address(0), bytes32(0));

        _holder = new ERC1155Holder();
        _recipient = new ERC1155Recipient();
    }

    function testSupportsInterface() public view {
        assertTrue(_holder.supportsInterface(type(IERC165).interfaceId));
        assertTrue(_holder.supportsInterface(type(IERC1155Receiver).interfaceId));
    }

    function testRecipientGasUsage(address operator, address from, uint256 tokenId, uint256 amount) public {
        _recipient.onERC1155Received(operator, from, tokenId, amount, "");
    }

    function testRecipientGasUsageBatch(
        address operator,
        address from,
        uint256[] memory tokenIds,
        uint256[] memory amounts
    ) public {
        _recipient.onERC1155BatchReceived(operator, from, tokenIds, amounts, "");
    }

    function testTransferAddsClaimForClaimant(
        address sender,
        address claimant,
        uint256 tokenId,
        uint256 amount,
        bool tightPacked
    ) public returns (address, address, uint256, uint256) {
        assumeUnusedAddress(sender);
        if (claimant != address(_recipient)) {
            assumeUnusedAddress(claimant);
        }
        amount = bound(amount, 1, 1000);

        // Mint tokens to sender first
        _token.mint(address(sender), tokenId, amount, "");

        // Transfer tokens to holder with claimant data
        bytes memory claimData = tightPacked ? abi.encodePacked(claimant) : abi.encode(claimant);
        vm.expectEmit(true, true, true, true);
        emit ClaimAdded(claimant, address(_token), tokenId, amount);
        vm.prank(sender);
        _token.safeTransferFrom(address(sender), address(_holder), tokenId, amount, claimData);

        // Verify holder holds the tokens
        assertEq(_token.balanceOf(claimant, tokenId), 0);
        assertEq(_token.balanceOf(address(_holder), tokenId), amount);

        // Verify claim was added
        assertEq(_holder.claims(claimant, address(_token), tokenId), amount);

        return (sender, claimant, tokenId, amount);
    }

    function testTransferAddsClaimForClaimantBatch(
        address sender,
        address claimant,
        uint256[] memory tokenIds,
        uint256[] memory amounts,
        bool tightPacked
    ) public returns (address, address, uint256[] memory, uint256[] memory) {
        assumeUnusedAddress(sender);
        if (claimant != address(_recipient)) {
            assumeUnusedAddress(claimant);
        }
        vm.assume(tokenIds.length > 0);
        uint256 tokenIdsLength = tokenIds.length > 10 ? 10 : tokenIds.length;
        vm.assume(amounts.length >= tokenIdsLength);
        assembly {
            // Fix array lengths
            mstore(tokenIds, tokenIdsLength)
            mstore(amounts, tokenIdsLength)
        }
        assumeNoDuplicates(tokenIds);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            amounts[i] = bound(amounts[i], 1, 1000);
            // Mint tokens to sender first
            _token.mint(address(sender), tokenIds[i], amounts[i], "");
        }

        bytes memory claimData = tightPacked ? abi.encodePacked(claimant) : abi.encode(claimant);
        vm.expectEmit(true, true, true, true);
        emit ClaimAddedBatch(claimant, address(_token), tokenIds, amounts);
        vm.prank(sender);
        _token.safeBatchTransferFrom(address(sender), address(_holder), tokenIds, amounts, claimData);

        // Verify holder holds the tokens
        for (uint256 i = 0; i < tokenIds.length; i++) {
            assertEq(_token.balanceOf(claimant, tokenIds[i]), 0);
            assertEq(_token.balanceOf(address(_holder), tokenIds[i]), amounts[i]);
            // Verify claim was added
            assertEq(_holder.claims(claimant, address(_token), tokenIds[i]), amounts[i]);
        }

        return (sender, claimant, tokenIds, amounts);
    }

    function testClaimSingleTokenToEOA(
        address sender,
        address claimant,
        uint256 tokenId,
        uint256 amount,
        bool tightPacked
    ) public {
        (sender, claimant, tokenId, amount) =
            testTransferAddsClaimForClaimant(sender, claimant, tokenId, amount, tightPacked);

        // Execute claim
        vm.expectEmit(true, true, true, true);
        emit Claimed(claimant, address(_token), tokenId, amount);
        _holder.claim(claimant, address(_token), tokenId);

        // Verify tokens transferred
        assertEq(_token.balanceOf(claimant, tokenId), amount);
        assertEq(_token.balanceOf(address(_holder), tokenId), 0);

        // Verify claim cleared
        assertEq(_holder.claims(claimant, address(_token), tokenId), 0);
    }

    function testClaimSingleTokenToRecipient(
        address sender,
        uint256 tokenId,
        uint256 amount,
        bool tightPacked
    ) public {
        (sender,, tokenId, amount) =
            testTransferAddsClaimForClaimant(sender, address(_recipient), tokenId, amount, tightPacked);

        // Execute claim
        vm.expectEmit(true, true, true, true);
        emit Claimed(address(_recipient), address(_token), tokenId, amount);
        _holder.claim(address(_recipient), address(_token), tokenId);

        // Verify tokens transferred
        assertEq(_token.balanceOf(address(_recipient), tokenId), amount);
        assertEq(_token.balanceOf(address(_holder), tokenId), 0);

        // Verify claim cleared
        assertEq(_holder.claims(address(_recipient), address(_token), tokenId), 0);
    }

    function testClaimBatchTokensToEOA(
        address sender,
        address claimant,
        uint256[] memory tokenIds,
        uint256[] memory amounts,
        bool tightPacked
    ) public {
        (sender, claimant, tokenIds, amounts) =
            testTransferAddsClaimForClaimantBatch(sender, claimant, tokenIds, amounts, tightPacked);

        // Test claim batch event
        vm.expectEmit(true, true, true, true);
        emit ClaimedBatch(claimant, address(_token), tokenIds, amounts);
        _holder.claimBatch(claimant, address(_token), tokenIds);

        // Verify tokens transferred
        for (uint256 i = 0; i < tokenIds.length; i++) {
            assertEq(_token.balanceOf(claimant, tokenIds[i]), amounts[i]);
            assertEq(_token.balanceOf(address(_holder), tokenIds[i]), 0);
            // Verify claim cleared
            assertEq(_holder.claims(claimant, address(_token), tokenIds[i]), 0);
        }
    }

    function testClaimBatchTokensToRecipient(
        address sender,
        uint256[] memory tokenIds,
        uint256[] memory amounts,
        bool tightPacked
    ) public {
        (sender,, tokenIds, amounts) =
            testTransferAddsClaimForClaimantBatch(sender, address(_recipient), tokenIds, amounts, tightPacked);

        // Test claim batch event
        vm.expectEmit(true, true, true, true);
        emit ClaimedBatch(address(_recipient), address(_token), tokenIds, amounts);
        _holder.claimBatch(address(_recipient), address(_token), tokenIds);

        // Verify tokens transferred
        for (uint256 i = 0; i < tokenIds.length; i++) {
            assertEq(_token.balanceOf(address(_recipient), tokenIds[i]), amounts[i]);
            assertEq(_token.balanceOf(address(_holder), tokenIds[i]), 0);
            // Verify claim cleared
            assertEq(_holder.claims(address(_recipient), address(_token), tokenIds[i]), 0);
        }
    }

    function testClaimantDecodingAddressZero(
        bool tightPacked
    ) public {
        // Address 0
        bytes memory claimData = tightPacked ? abi.encodePacked(address(0)) : abi.encode(address(0));
        vm.expectRevert(ERC1155Holder.InvalidClaimant.selector);
        _holder.onERC1155Received(address(0), address(_token), 0, 0, claimData);
        vm.expectRevert(ERC1155Holder.InvalidClaimant.selector);
        _holder.onERC1155BatchReceived(address(0), address(_token), new uint256[](1), new uint256[](1), claimData);
    }

    function testClaimantDecodingInvalidData(
        bytes memory claimData
    ) public {
        vm.assume(claimData.length != 20 && claimData.length != 32);
        vm.expectRevert(ERC1155Holder.InvalidClaimant.selector);
        _holder.onERC1155Received(address(0), address(_token), 0, 0, claimData);
        vm.expectRevert(ERC1155Holder.InvalidClaimant.selector);
        _holder.onERC1155BatchReceived(address(0), address(_token), new uint256[](1), new uint256[](1), claimData);
    }

}
