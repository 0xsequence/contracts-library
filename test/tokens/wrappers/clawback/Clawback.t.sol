// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { ClawbackTestBase, IGenericToken } from "./ClawbackTestBase.sol";

import { Clawback } from "src/tokens/wrappers/clawback/Clawback.sol";
import { IClawback, IClawbackFunctions, IClawbackSignals } from "src/tokens/wrappers/clawback/IClawback.sol";

import { IERC1155 } from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import { IERC165 } from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

import { ISignalsImplicitMode } from "signals-implicit-mode/src/helper/SignalsImplicitMode.sol";

import { ERC1155 } from "solady/tokens/ERC1155.sol";

contract ClawbackTest is ClawbackTestBase, IClawbackSignals {

    //
    // Template
    //
    function testAddTemplate(
        address admin,
        uint56 duration,
        bool destructionOnly,
        bool transferOpen
    ) public returns (uint32 templateId) {
        vm.assume(admin != address(0));

        vm.expectEmit(true, true, true, true, address(clawback));
        emit TemplateAdded(0, admin, duration, destructionOnly, transferOpen);
        vm.prank(admin);
        templateId = clawback.addTemplate(duration, destructionOnly, transferOpen);

        IClawbackFunctions.Template memory template = clawback.getTemplate(templateId);
        assertEq(template.admin, admin);
        assertEq(template.duration, duration);
        assertEq(template.destructionOnly, destructionOnly);
        assertEq(template.transferOpen, transferOpen);
    }

    function testUpdateTemplateValid(
        address admin,
        uint56 durationA,
        bool destructionOnlyA,
        bool transferOpenA,
        uint56 durationB,
        bool destructionOnlyB,
        bool transferOpenB
    ) public {
        durationB = uint56(bound(durationB, 0, durationA));
        destructionOnlyB = destructionOnlyA || destructionOnlyB;
        transferOpenB = transferOpenA || transferOpenB;

        uint32 templateId = testAddTemplate(admin, durationA, destructionOnlyA, transferOpenA);

        vm.expectEmit(true, true, true, true, address(clawback));
        emit TemplateUpdated(templateId, durationB, destructionOnlyB, transferOpenB);
        vm.prank(admin);
        clawback.updateTemplate(templateId, durationB, destructionOnlyB, transferOpenB);
    }

    function testUpdateTemplateInvalidCaller(
        address admin,
        address nonAdmin,
        bool isNonAdminOperator,
        uint56 duration,
        bool destructionOnly,
        bool transferOpen
    ) public {
        vm.assume(admin != nonAdmin);

        uint32 templateId = testAddTemplate(admin, duration, destructionOnly, transferOpen);

        if (isNonAdminOperator) {
            // Operator status doesn't enable permissions for template updates
            vm.prank(admin);
            clawback.updateTemplateOperator(templateId, nonAdmin, true);
        }

        vm.expectRevert(Unauthorized.selector);
        vm.prank(nonAdmin);
        clawback.updateTemplate(templateId, duration, destructionOnly, transferOpen);
    }

    function testUpdateTemplateInvalidDuration(
        address admin,
        uint56 durationA,
        bool destructionOnly,
        bool transferOpen,
        uint56 durationB
    ) public {
        vm.assume(durationB > durationA);

        uint32 templateId = testAddTemplate(admin, durationA, destructionOnly, transferOpen);

        vm.expectRevert(abi.encodeWithSelector(InvalidTemplateChange.selector, "Duration must be equal or decrease"));
        vm.prank(admin);
        clawback.updateTemplate(templateId, durationB, destructionOnly, transferOpen);
    }

    function testUpdateTemplateInvalidDestructionOnly() public {
        // No reason to fuzz this
        uint32 templateId = testAddTemplate(address(this), 0, true, false);

        vm.expectRevert(abi.encodeWithSelector(InvalidTemplateChange.selector, "Cannot change from destruction only"));
        clawback.updateTemplate(templateId, 0, false, false);
    }

    function testUpdateTemplateInvalidTransferOpen() public {
        // No reason to fuzz this
        uint32 templateId = testAddTemplate(address(this), 0, false, true);

        vm.expectRevert(abi.encodeWithSelector(InvalidTemplateChange.selector, "Cannot change from transfer open"));
        clawback.updateTemplate(templateId, 0, false, false);
    }

    function testUpdateTemplateAdminInvalidCaller(address admin, address nonAdmin, bool isNonAdminOperator) public {
        vm.assume(admin != nonAdmin);
        uint32 templateId = testAddTemplate(admin, 0, false, true);

        if (isNonAdminOperator) {
            // Operator status doesn't enable permissions for template updates
            vm.prank(admin);
            clawback.updateTemplateOperator(templateId, nonAdmin, true);
        }

        vm.expectRevert(Unauthorized.selector);
        vm.prank(nonAdmin);
        clawback.updateTemplateAdmin(templateId, address(this));
    }

    function testUpdateTemplateAdminInvalidAdmin() public {
        // No reason to fuzz this
        uint32 templateId = testAddTemplate(address(this), 0, false, true);

        vm.expectRevert(abi.encodeWithSelector(InvalidTemplateChange.selector, "Admin cannot be zero address"));
        clawback.updateTemplateAdmin(templateId, address(0));
    }

    function testUpdateTemplateAdmin(
        address adminA,
        address adminB,
        uint56 duration,
        bool destructionOnly,
        bool transferOpen
    ) public safeAddress(adminA) safeAddress(adminB) {
        vm.assume(adminA != adminB);
        uint32 templateId = testAddTemplate(adminA, duration, destructionOnly, transferOpen);

        vm.expectEmit(true, true, true, true, address(clawback));
        emit TemplateAdminUpdated(templateId, adminB);
        vm.prank(adminA);
        clawback.updateTemplateAdmin(templateId, adminB);

        // AdminA has no perms
        vm.expectRevert(Unauthorized.selector);
        vm.prank(adminA);
        clawback.updateTemplate(templateId, duration, destructionOnly, transferOpen);
        vm.expectRevert(Unauthorized.selector);
        vm.prank(adminA);
        clawback.updateTemplateAdmin(templateId, adminA);

        // AdminB has perms
        vm.startPrank(adminB);
        clawback.updateTemplate(templateId, duration, destructionOnly, transferOpen);
        clawback.updateTemplateAdmin(templateId, adminB);
        vm.stopPrank();
    }

    function testAddTemplateTransfererInvalidCaller(
        address admin,
        address nonAdmin,
        bool isNonAdminOperator,
        address transferer
    ) public {
        vm.assume(admin != nonAdmin);
        uint32 templateId = testAddTemplate(admin, 0, false, true);

        if (isNonAdminOperator) {
            // Operator status doesn't enable permissions for template updates
            vm.prank(admin);
            clawback.updateTemplateOperator(templateId, nonAdmin, true);
        }

        vm.expectRevert(Unauthorized.selector);
        vm.prank(nonAdmin);
        clawback.addTemplateTransferer(templateId, transferer);
    }

    function testAddTemplateTransferer(address admin, address transferer) public {
        uint32 templateId = testAddTemplate(admin, 0, false, true);

        vm.expectEmit(true, true, true, true, address(clawback));
        emit TemplateTransfererAdded(templateId, transferer);
        vm.prank(admin);
        clawback.addTemplateTransferer(templateId, transferer);

        assertTrue(clawback.templateTransferers(templateId, transferer));
    }

    function testUpdateTemplateOperatorInvalidCaller(
        address admin,
        address nonAdmin,
        bool isNonAdminOperator,
        address operator,
        bool allowed
    ) public {
        vm.assume(admin != nonAdmin);
        uint32 templateId = testAddTemplate(admin, 0, false, true);

        if (isNonAdminOperator) {
            // Operator status doesn't enable permissions for template updates
            vm.prank(admin);
            clawback.updateTemplateOperator(templateId, nonAdmin, true);
        }

        vm.expectRevert(Unauthorized.selector);
        vm.prank(nonAdmin);
        clawback.updateTemplateOperator(templateId, operator, allowed);
    }

    function testUpdateTemplateOperator(address admin, address operator, bool allowed) public {
        uint32 templateId = testAddTemplate(admin, 0, false, true);

        vm.expectEmit(true, true, true, true, address(clawback));
        emit TemplateOperatorUpdated(templateId, operator, allowed);
        vm.prank(admin);
        clawback.updateTemplateOperator(templateId, operator, allowed);

        if (allowed) {
            assertTrue(clawback.templateOperators(templateId, operator));
        } else {
            assertFalse(clawback.templateOperators(templateId, operator));
        }
    }

    //
    // Wrap
    //
    function testWrap(
        address templateAdmin,
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        address receiver
    ) public safeAddress(receiver) {
        IClawbackFunctions.TokenType tokenType = _toTokenType(tokenTypeNum);
        address tokenAddr;
        (tokenAddr, tokenId, amount) = _validParams(tokenType, tokenId, amount);

        IGenericToken(tokenAddr).mint(address(this), tokenId, amount);
        IGenericToken(tokenAddr).approve(address(this), address(clawback), tokenId, amount);

        uint32 templateId = testAddTemplate(templateAdmin, 1, false, false);

        vm.expectEmit(true, true, true, true, address(clawback));
        emit Wrapped(0, templateId, tokenAddr, tokenId, amount, address(this), receiver);
        uint256 wrappedTokenId = clawback.wrap(templateId, tokenType, tokenAddr, tokenId, amount, receiver);

        assertEq(IGenericToken(tokenAddr).balanceOf(receiver, tokenId), 0);
        assertEq(IGenericToken(tokenAddr).balanceOf(address(this), tokenId), 0);
        assertEq(IGenericToken(tokenAddr).balanceOf(address(clawback), tokenId), amount);
        IClawbackFunctions.TokenDetails memory details = clawback.getTokenDetails(0);
        assertEq(clawback.balanceOf(receiver, wrappedTokenId), amount);
        assertEq(clawback.balanceOf(address(this), wrappedTokenId), 0);
        assertEq(details.templateId, templateId);
        assertEq(details.lockedAt, uint56(block.timestamp));
        assertEq(uint8(details.tokenType), uint8(tokenType));
        assertEq(details.tokenAddr, tokenAddr);
        assertEq(details.tokenId, tokenId);
    }

    // Note forge coverage misreports this as not covered
    function testWrapInvalidTokenType(
        address templateAdmin,
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount
    ) public {
        vm.assume(tokenTypeNum > 3);

        IClawbackFunctions.TokenType tokenType = _toTokenType(tokenTypeNum);
        address tokenAddr;
        (tokenAddr, tokenId, amount) = _validParams(tokenType, tokenId, amount);

        IGenericToken(tokenAddr).mint(address(this), tokenId, amount);
        IGenericToken(tokenAddr).approve(address(this), address(clawback), tokenId, amount);

        uint32 templateId = testAddTemplate(templateAdmin, 1, false, false);

        bytes memory data = abi.encodeWithSelector(
            IClawbackFunctions.wrap.selector, templateId, tokenTypeNum, tokenAddr, tokenId, amount
        );
        vm.expectRevert(InvalidTokenTransfer.selector);
        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = address(clawback).call(data);

        assertFalse(success);
    }

    function testWrapInvalidAmount(
        address templateAdmin,
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        address receiver
    ) public {
        IClawbackFunctions.TokenType tokenType = _toTokenType(tokenTypeNum);
        address tokenAddr;
        (tokenAddr, tokenId, amount) = _validParams(tokenType, tokenId, amount);

        IGenericToken(tokenAddr).mint(address(this), tokenId, amount);
        IGenericToken(tokenAddr).approve(address(this), address(clawback), tokenId, amount);

        uint32 templateId = testAddTemplate(templateAdmin, 1, false, false);

        if (tokenAddr == address(erc20) && tokenTypeNum % 2 == 0) {
            // Sometimes flip tokenId
            tokenId = 1;
        }
        amount = 0;

        vm.expectRevert(InvalidTokenTransfer.selector);
        clawback.wrap(templateId, tokenType, tokenAddr, tokenId, amount, receiver);
    }

    function testWrapInvalidTemplate(
        uint32 templateId,
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        address receiver
    ) public {
        IClawbackFunctions.TokenType tokenType = _toTokenType(tokenTypeNum);
        address tokenAddr;
        (tokenAddr, tokenId, amount) = _validParams(tokenType, tokenId, amount);

        IGenericToken(tokenAddr).mint(address(this), tokenId, amount);
        IGenericToken(tokenAddr).approve(address(this), address(clawback), tokenId, amount);

        vm.expectRevert(InvalidTemplate.selector);
        clawback.wrap(templateId, tokenType, tokenAddr, tokenId, amount, receiver);
    }

    function testWrapInvalidRewrapping(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration,
        address receiver
    ) public {
        WrapSetupResult memory result =
            _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration, address(this));
        amount = result.amount;

        vm.expectRevert(InvalidTokenTransfer.selector);
        clawback.wrap(
            result.templateId,
            IClawbackFunctions.TokenType.ERC1155,
            address(clawback),
            result.wrappedTokenId,
            amount,
            receiver
        );
    }

    //
    // Add To Wrap
    //
    function testAddToWrap(
        address templateAdmin,
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration,
        address receiver,
        uint64 addToWrapTimestamp
    ) public safeAddress(receiver) {
        IClawbackFunctions.TokenType tokenType = _toTokenType(tokenTypeNum);
        vm.assume(tokenType != IClawbackFunctions.TokenType.ERC721);

        WrapSetupResult memory result =
            _wrapSetup(templateAdmin, tokenTypeNum, tokenId, amount, duration, address(this));
        amount = result.amount;
        vm.assume(amount < type(uint256).max / 2); // Prevent overflow
        tokenId = result.tokenId;
        duration = result.duration;

        IGenericToken(result.tokenAddr).mint(address(this), tokenId, amount);
        IGenericToken(result.tokenAddr).approve(address(this), address(clawback), tokenId, amount);

        vm.warp(addToWrapTimestamp); // Doesn't matter

        vm.expectEmit(true, true, true, true, address(clawback));
        emit Wrapped(0, result.templateId, result.tokenAddr, tokenId, amount, address(this), receiver);
        clawback.addToWrap(result.wrappedTokenId, amount, receiver);

        assertEq(IGenericToken(result.tokenAddr).balanceOf(receiver, tokenId), 0);
        assertEq(IGenericToken(result.tokenAddr).balanceOf(address(this), tokenId), 0);
        assertEq(IGenericToken(result.tokenAddr).balanceOf(address(clawback), tokenId), amount * 2); // Wrap and add
        assertEq(clawback.balanceOf(address(this), result.wrappedTokenId), amount); // Wrap
        assertEq(clawback.balanceOf(receiver, result.wrappedTokenId), amount); // Add
    }

    function testAddToWrapInvalidWrappedId(uint256 wrappedTokenId, uint256 amount, address receiver) public {
        vm.expectRevert(InvalidTokenTransfer.selector);
        clawback.addToWrap(wrappedTokenId, amount, receiver);
    }

    //
    // Unwrap
    //
    function testUnwrap(
        address templateAdmin,
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration,
        uint64 unwrapTimestamp
    ) public {
        WrapSetupResult memory result =
            _wrapSetup(templateAdmin, tokenTypeNum, tokenId, amount, duration, address(this));
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;
        unwrapTimestamp = uint64(bound(unwrapTimestamp, block.timestamp + duration, type(uint64).max));

        vm.warp(unwrapTimestamp);
        vm.expectEmit(true, true, true, true, address(clawback));
        emit Unwrapped(result.wrappedTokenId, result.templateId, result.tokenAddr, tokenId, amount, address(this));
        clawback.unwrap(result.wrappedTokenId, address(this), amount);

        assertEq(IGenericToken(result.tokenAddr).balanceOf(address(this), tokenId), amount, "Token balance of owner");
        assertEq(IGenericToken(result.tokenAddr).balanceOf(address(clawback), tokenId), 0, "Token balance of clawback");
        assertEq(clawback.balanceOf(address(this), result.wrappedTokenId), 0, "Clawback balance of owner");
        assertEq(clawback.balanceOf(address(clawback), result.wrappedTokenId), 0, "Clawback balance of clawback"); // Burned
    }

    function testUnwrapAfterTransfer(
        address templateAdmin,
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration,
        uint64 unwrapTimestamp,
        address tokenOwner
    ) public safeAddress(tokenOwner) {
        WrapSetupResult memory result =
            _wrapSetup(templateAdmin, tokenTypeNum, tokenId, amount, duration, address(this));
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;
        unwrapTimestamp = uint64(bound(unwrapTimestamp, block.timestamp + duration, type(uint64).max));

        vm.prank(templateAdmin);
        clawback.updateTemplate(result.templateId, duration, false, true);
        clawback.safeTransferFrom(address(this), tokenOwner, result.wrappedTokenId, amount, "");

        vm.warp(unwrapTimestamp);
        vm.expectEmit(true, true, true, true, address(clawback));
        emit Unwrapped(result.wrappedTokenId, result.templateId, result.tokenAddr, tokenId, amount, tokenOwner);
        vm.prank(tokenOwner);
        clawback.unwrap(result.wrappedTokenId, tokenOwner, amount);

        assertEq(IGenericToken(result.tokenAddr).balanceOf(tokenOwner, tokenId), amount, "Token balance of token owner");
        assertEq(IGenericToken(result.tokenAddr).balanceOf(address(this), tokenId), 0, "Token balance of old owner");
        assertEq(IGenericToken(result.tokenAddr).balanceOf(address(clawback), tokenId), 0, "Token balance of clawback");
        assertEq(clawback.balanceOf(tokenOwner, result.wrappedTokenId), 0, "Clawback balance of token owner");
        assertEq(clawback.balanceOf(address(this), result.wrappedTokenId), 0, "Clawback balance of old owner");
        assertEq(clawback.balanceOf(address(clawback), result.wrappedTokenId), 0, "Clawback balance of clawback"); // Burned
    }

    function testUnwrapInvalidToken(
        address templateAdmin,
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 wrongWrappedTokenId,
        uint256 amount,
        uint56 duration
    ) public {
        vm.assume(wrongWrappedTokenId != 0);
        WrapSetupResult memory result =
            _wrapSetup(templateAdmin, tokenTypeNum, tokenId, amount, duration, address(this));
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;
        vm.assume(wrongWrappedTokenId != result.wrappedTokenId);

        vm.warp(block.timestamp + duration);
        vm.expectRevert(ERC1155.InsufficientBalance.selector);
        clawback.unwrap(wrongWrappedTokenId, address(this), amount);
    }

    function testUnwrapTokenLocked(
        address templateAdmin,
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration
    ) public {
        WrapSetupResult memory result =
            _wrapSetup(templateAdmin, tokenTypeNum, tokenId, amount, duration, address(this));
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;

        // Don't warp to unlock

        vm.expectRevert(TokenLocked.selector);
        clawback.unwrap(result.wrappedTokenId, address(this), amount);
    }

    function testUnwrapInvalidAmount(
        address templateAdmin,
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint256 invalidAmount,
        uint56 duration
    ) public {
        WrapSetupResult memory result =
            _wrapSetup(templateAdmin, tokenTypeNum, tokenId, amount, duration, address(this));
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;
        vm.assume(amount != type(uint256).max);
        invalidAmount = bound(invalidAmount, amount + 1, type(uint256).max);

        vm.warp(block.timestamp + duration);
        vm.expectRevert(ERC1155.InsufficientBalance.selector);
        clawback.unwrap(result.wrappedTokenId, address(this), invalidAmount);
    }

    function testUnwrapByOperator(
        address templateAdmin,
        address operator,
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration,
        uint64 unwrapTimestamp
    ) public {
        vm.assume(operator != address(this));

        WrapSetupResult memory result =
            _wrapSetup(templateAdmin, tokenTypeNum, tokenId, amount, duration, address(this));
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;

        vm.prank(templateAdmin);
        clawback.updateTemplateOperator(result.templateId, operator, true);

        vm.warp(unwrapTimestamp); // Allowed any time
        vm.expectEmit(true, true, true, true, address(clawback));
        emit Unwrapped(result.wrappedTokenId, result.templateId, result.tokenAddr, tokenId, amount, operator);
        vm.prank(operator);
        clawback.unwrap(result.wrappedTokenId, address(this), amount);

        assertEq(IGenericToken(result.tokenAddr).balanceOf(address(this), tokenId), amount, "Token balance of owner");
        assertEq(IGenericToken(result.tokenAddr).balanceOf(address(clawback), tokenId), 0, "Token balance of clawback");
        assertEq(IGenericToken(result.tokenAddr).balanceOf(operator, tokenId), 0, "Token balance of operator");
        assertEq(clawback.balanceOf(address(this), result.wrappedTokenId), 0, "Clawback balance of owner");
        assertEq(clawback.balanceOf(address(clawback), result.wrappedTokenId), 0, "Clawback balance of clawback"); // Burned
        assertEq(clawback.balanceOf(operator, result.wrappedTokenId), 0, "Clawback balance of operator");
    }

    function testUnwrapByInvalidOperator(
        address templateAdmin,
        address operator,
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration
    ) public {
        vm.assume(operator != address(this));

        WrapSetupResult memory result =
            _wrapSetup(templateAdmin, tokenTypeNum, tokenId, amount, duration, address(this));
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;

        vm.expectRevert(Unauthorized.selector);
        vm.prank(operator);
        clawback.unwrap(result.wrappedTokenId, address(this), amount);
    }

    //
    // Clawback
    //
    function testClawback(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration,
        address operator,
        address receiver
    ) public safeAddress(receiver) {
        WrapSetupResult memory result =
            _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration, address(this));
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;

        clawback.updateTemplateOperator(result.templateId, operator, true);

        vm.expectEmit(true, true, true, true, address(clawback));
        emit ClawedBack(
            result.wrappedTokenId,
            result.templateId,
            result.tokenAddr,
            tokenId,
            amount,
            operator,
            address(this),
            receiver
        );
        vm.prank(operator);
        clawback.clawback(result.wrappedTokenId, address(this), receiver, amount);

        assertEq(IGenericToken(result.tokenAddr).balanceOf(receiver, tokenId), amount, "Token balance of receiver");
        assertEq(IGenericToken(result.tokenAddr).balanceOf(address(this), tokenId), 0, "Token balance of owner");
        assertEq(IGenericToken(result.tokenAddr).balanceOf(address(clawback), tokenId), 0, "Token balance of clawback");
        assertEq(clawback.balanceOf(receiver, result.wrappedTokenId), 0, "Clawback balance of receiver");
        assertEq(clawback.balanceOf(address(this), result.wrappedTokenId), 0, "Clawback balance of owner");
        assertEq(clawback.balanceOf(address(clawback), result.wrappedTokenId), 0, "Clawback balance of clawback");
    }

    function testClawbackAfterTransfer(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration,
        address operator,
        address tokenOwner,
        address receiver
    ) public safeAddress(receiver) safeAddress(tokenOwner) {
        vm.assume(receiver != tokenOwner);

        WrapSetupResult memory result =
            _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration, address(this));
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;

        clawback.updateTemplate(result.templateId, duration, false, true);
        clawback.updateTemplateOperator(result.templateId, operator, true);

        clawback.safeTransferFrom(address(this), tokenOwner, result.wrappedTokenId, amount, "");

        vm.expectEmit(true, true, true, true, address(clawback));
        emit ClawedBack(
            result.wrappedTokenId, result.templateId, result.tokenAddr, tokenId, amount, operator, tokenOwner, receiver
        );
        vm.prank(operator);
        clawback.clawback(result.wrappedTokenId, tokenOwner, receiver, amount);

        assertEq(IGenericToken(result.tokenAddr).balanceOf(tokenOwner, tokenId), 0, "Token balance of token owner");
        assertEq(IGenericToken(result.tokenAddr).balanceOf(receiver, tokenId), amount, "Token balance of receiver");
        assertEq(IGenericToken(result.tokenAddr).balanceOf(address(this), tokenId), 0, "Token balance of owner");
        assertEq(IGenericToken(result.tokenAddr).balanceOf(address(clawback), tokenId), 0, "Token balance of clawback");
        assertEq(clawback.balanceOf(tokenOwner, result.wrappedTokenId), 0, "Clawback balance of token owner"); // Burned
        assertEq(clawback.balanceOf(receiver, result.wrappedTokenId), 0, "Clawback balance of receiver");
        assertEq(clawback.balanceOf(address(this), result.wrappedTokenId), 0, "Clawback balance of owner");
        assertEq(clawback.balanceOf(address(clawback), result.wrappedTokenId), 0, "Clawback balance of clawback");
    }

    function testClawbackInvalidUnlocked(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration,
        address operator,
        address receiver
    ) public safeAddress(receiver) {
        WrapSetupResult memory result =
            _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration, address(this));
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;

        clawback.updateTemplateOperator(result.templateId, operator, true);

        vm.warp(block.timestamp + duration);

        vm.expectRevert(TokenUnlocked.selector);
        vm.prank(operator);
        clawback.clawback(result.wrappedTokenId, address(this), receiver, amount);
    }

    function testClawbackDestructionOnly(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration,
        address operator
    ) public {
        WrapSetupResult memory result =
            _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration, address(this));
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;

        clawback.updateTemplate(result.templateId, duration, true, false);
        clawback.updateTemplateOperator(result.templateId, operator, true);

        address burnAddress = clawback.BURN_ADDRESS();

        vm.expectEmit(true, true, true, true, address(clawback));
        emit ClawedBack(
            result.wrappedTokenId,
            result.templateId,
            result.tokenAddr,
            tokenId,
            amount,
            operator,
            address(this),
            burnAddress
        );
        vm.prank(operator);
        clawback.clawback(result.wrappedTokenId, address(this), burnAddress, amount);

        assertEq(IGenericToken(result.tokenAddr).balanceOf(burnAddress, tokenId), amount, "Token balance of receiver");
        assertEq(IGenericToken(result.tokenAddr).balanceOf(address(this), tokenId), 0, "Token balance of owner");
        assertEq(IGenericToken(result.tokenAddr).balanceOf(address(clawback), tokenId), 0, "Token balance of clawback");
        assertEq(clawback.balanceOf(burnAddress, result.wrappedTokenId), 0, "Clawback balance of receiver");
        assertEq(clawback.balanceOf(address(this), result.wrappedTokenId), 0, "Clawback balance of owner");
        assertEq(clawback.balanceOf(address(clawback), result.wrappedTokenId), 0, "Clawback balance of clawback");
    }

    function testClawbackDestructionOnlyInvalidReceiver(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration,
        address operator,
        address receiver
    ) public safeAddress(receiver) {
        address burnAddress = clawback.BURN_ADDRESS();
        vm.assume(receiver != burnAddress);

        WrapSetupResult memory result =
            _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration, address(this));
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;

        clawback.updateTemplate(result.templateId, duration, true, false);
        clawback.updateTemplateOperator(result.templateId, operator, true);

        vm.expectRevert(InvalidReceiver.selector);
        vm.prank(operator);
        clawback.clawback(result.wrappedTokenId, address(this), receiver, amount);
    }

    function testClawbackInvalidCaller(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration,
        address operator,
        address receiver
    ) public {
        WrapSetupResult memory result =
            _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration, address(this));
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;

        vm.expectRevert(Unauthorized.selector);
        vm.prank(operator);
        clawback.clawback(result.wrappedTokenId, address(this), receiver, amount);
    }

    //
    // Emergency Clawback
    //
    function testEmergencyClawback(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration,
        address operator,
        address receiver
    ) public safeAddress(receiver) {
        WrapSetupResult memory result =
            _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration, address(this));
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;

        clawback.updateTemplateOperator(result.templateId, operator, true);

        vm.expectEmit(true, true, true, true, address(clawback));
        emit EmergencyClawedBack(
            result.wrappedTokenId, result.templateId, result.tokenAddr, tokenId, amount, operator, receiver
        );
        vm.prank(operator);
        clawback.emergencyClawback(result.wrappedTokenId, receiver, amount);

        assertEq(IGenericToken(result.tokenAddr).balanceOf(receiver, tokenId), amount, "Token balance of receiver");
        assertEq(IGenericToken(result.tokenAddr).balanceOf(address(this), tokenId), 0, "Token balance of owner");
        assertEq(IGenericToken(result.tokenAddr).balanceOf(address(clawback), tokenId), 0, "Token balance of clawback");
        assertEq(clawback.balanceOf(receiver, result.wrappedTokenId), 0, "Clawback balance of receiver");
        assertEq(clawback.balanceOf(address(this), result.wrappedTokenId), amount, "Clawback balance of owner"); // Unaffected
        assertEq(clawback.balanceOf(address(clawback), result.wrappedTokenId), 0, "Clawback balance of clawback");
    }

    function testEmergencyClawbackAfterTransfer(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration,
        address operator,
        address tokenOwner,
        address receiver
    ) public safeAddress(receiver) safeAddress(tokenOwner) {
        vm.assume(receiver != tokenOwner);

        WrapSetupResult memory result =
            _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration, address(this));
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;

        clawback.updateTemplate(result.templateId, duration, false, true);
        clawback.updateTemplateOperator(result.templateId, operator, true);

        clawback.safeTransferFrom(address(this), tokenOwner, result.wrappedTokenId, amount, "");

        vm.expectEmit(true, true, true, true, address(clawback));
        emit EmergencyClawedBack(
            result.wrappedTokenId, result.templateId, result.tokenAddr, tokenId, amount, operator, receiver
        );
        vm.prank(operator);
        clawback.emergencyClawback(result.wrappedTokenId, receiver, amount);

        assertEq(IGenericToken(result.tokenAddr).balanceOf(receiver, tokenId), amount, "Token balance of receiver");
        assertEq(IGenericToken(result.tokenAddr).balanceOf(tokenOwner, tokenId), 0, "Token balance of token owner");
        assertEq(IGenericToken(result.tokenAddr).balanceOf(address(this), tokenId), 0, "Token balance of old owner");
        assertEq(IGenericToken(result.tokenAddr).balanceOf(address(clawback), tokenId), 0, "Token balance of clawback");
        assertEq(clawback.balanceOf(receiver, result.wrappedTokenId), 0, "Clawback balance of receiver");
        assertEq(clawback.balanceOf(tokenOwner, result.wrappedTokenId), amount, "Clawback balance of token owner"); // Unaffected
        assertEq(clawback.balanceOf(address(this), result.wrappedTokenId), 0, "Clawback balance of old owner");
        assertEq(clawback.balanceOf(address(clawback), result.wrappedTokenId), 0, "Clawback balance of clawback");
    }

    function testEmergencyClawbackInvalidUnlocked(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration,
        address operator,
        address receiver
    ) public safeAddress(receiver) {
        WrapSetupResult memory result =
            _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration, address(this));
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;

        clawback.updateTemplateOperator(result.templateId, operator, true);

        vm.warp(block.timestamp + duration);

        vm.expectRevert(TokenUnlocked.selector);
        vm.prank(operator);
        clawback.emergencyClawback(result.wrappedTokenId, receiver, amount);
    }

    function testEmergencyClawbackDestructionOnly(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration,
        address operator
    ) public {
        WrapSetupResult memory result =
            _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration, address(this));
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;

        clawback.updateTemplate(result.templateId, duration, true, false);
        clawback.updateTemplateOperator(result.templateId, operator, true);

        address burnAddress = clawback.BURN_ADDRESS();

        vm.expectEmit(true, true, true, true, address(clawback));
        emit EmergencyClawedBack(
            result.wrappedTokenId, result.templateId, result.tokenAddr, tokenId, amount, operator, burnAddress
        );
        vm.prank(operator);
        clawback.emergencyClawback(result.wrappedTokenId, burnAddress, amount);

        assertEq(
            IGenericToken(result.tokenAddr).balanceOf(burnAddress, tokenId), amount, "Token balance of burn address"
        );
        assertEq(IGenericToken(result.tokenAddr).balanceOf(address(this), tokenId), 0, "Token balance of owner");
        assertEq(IGenericToken(result.tokenAddr).balanceOf(address(clawback), tokenId), 0, "Token balance of clawback");
        assertEq(clawback.balanceOf(burnAddress, result.wrappedTokenId), 0, "Clawback balance of burn address");
        assertEq(clawback.balanceOf(address(this), result.wrappedTokenId), amount, "Clawback balance of owner"); // Unaffected
        assertEq(clawback.balanceOf(address(clawback), result.wrappedTokenId), 0, "Clawback balance of clawback");
    }

    function testEmergencyClawbackDestructionOnlyInvalidReceiver(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration,
        address operator,
        address receiver
    ) public safeAddress(receiver) {
        address burnAddress = clawback.BURN_ADDRESS();
        vm.assume(receiver != burnAddress);

        WrapSetupResult memory result =
            _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration, address(this));
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;

        clawback.updateTemplate(result.templateId, duration, true, false);
        clawback.updateTemplateOperator(result.templateId, operator, true);

        vm.expectRevert(InvalidReceiver.selector);
        vm.prank(operator);
        clawback.emergencyClawback(result.wrappedTokenId, receiver, amount);
    }

    function testEmergencyClawbackInvalidCaller(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration,
        address operator,
        address receiver
    ) public {
        WrapSetupResult memory result =
            _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration, address(this));
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;

        vm.expectRevert(Unauthorized.selector);
        vm.prank(operator);
        clawback.emergencyClawback(result.wrappedTokenId, receiver, amount);
    }

    //
    // Transfer
    //
    function testTransferOpen(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration,
        uint64 transferTimestamp,
        address receiver
    ) public safeAddress(receiver) {
        WrapSetupResult memory result =
            _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration, address(this));
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;

        clawback.updateTemplate(result.templateId, duration, false, true);

        vm.warp(transferTimestamp); // Doesn't matter if locked or unlocked

        clawback.safeTransferFrom(address(this), receiver, result.wrappedTokenId, amount, "");

        assertEq(clawback.balanceOf(receiver, result.wrappedTokenId), amount, "Clawback balance of receiver");
        assertEq(clawback.balanceOf(address(this), result.wrappedTokenId), 0, "Clawback balance of owner");
    }

    function testTransferByTransfererAsOperator(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration,
        uint64 transferTimestamp,
        bool transferOpen,
        address transferer,
        address receiver,
        bool batch
    ) public safeAddress(receiver) {
        WrapSetupResult memory result =
            _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration, address(this));
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;

        clawback.updateTemplate(result.templateId, duration, false, transferOpen); // Doesn't matter
        clawback.addTemplateTransferer(result.templateId, transferer);

        // Approval still required when operator
        clawback.setApprovalForAll(transferer, true);

        vm.warp(transferTimestamp); // Doesn't matter if locked or unlocked

        vm.prank(transferer);
        if (batch) {
            uint256[] memory tokenIds = new uint256[](1);
            tokenIds[0] = result.wrappedTokenId;
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = amount;
            clawback.safeBatchTransferFrom(address(this), receiver, tokenIds, amounts, "");
        } else {
            clawback.safeTransferFrom(address(this), receiver, result.wrappedTokenId, amount, "");
        }

        assertEq(clawback.balanceOf(receiver, result.wrappedTokenId), amount, "Clawback balance of receiver");
        assertEq(clawback.balanceOf(address(this), result.wrappedTokenId), 0, "Clawback balance of owner");
    }

    function testTransferByTransfererAsTo(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration,
        uint64 transferTimestamp,
        bool transferOpen,
        address transferer,
        bool batch
    ) public safeAddress(transferer) {
        WrapSetupResult memory result =
            _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration, address(this));
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;

        clawback.updateTemplate(result.templateId, duration, false, transferOpen); // Doesn't matter
        clawback.addTemplateTransferer(result.templateId, transferer);

        vm.warp(transferTimestamp); // Doesn't matter if locked or unlocked

        if (batch) {
            uint256[] memory tokenIds = new uint256[](1);
            tokenIds[0] = result.wrappedTokenId;
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = amount;
            clawback.safeBatchTransferFrom(address(this), transferer, tokenIds, amounts, "");
        } else {
            clawback.safeTransferFrom(address(this), transferer, result.wrappedTokenId, amount, "");
        }

        assertEq(clawback.balanceOf(transferer, result.wrappedTokenId), amount, "Clawback balance of transferer");
        assertEq(clawback.balanceOf(address(this), result.wrappedTokenId), 0, "Clawback balance of owner");
    }

    function testTransferByTransfererAsFrom(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration,
        uint64 transferTimestamp,
        bool transferOpen,
        address transferer,
        bool batch
    ) public safeAddress(transferer) {
        WrapSetupResult memory result =
            _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration, address(this));
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;

        clawback.updateTemplate(result.templateId, duration, false, transferOpen); // Doesn't matter
        clawback.addTemplateTransferer(result.templateId, transferer);

        vm.warp(transferTimestamp); // Doesn't matter if locked or unlocked

        if (batch) {
            uint256[] memory tokenIds = new uint256[](1);
            tokenIds[0] = result.wrappedTokenId;
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = amount;
            clawback.safeBatchTransferFrom(address(this), transferer, tokenIds, amounts, "");
        } else {
            clawback.safeTransferFrom(address(this), transferer, result.wrappedTokenId, amount, "");
        }

        assertEq(clawback.balanceOf(transferer, result.wrappedTokenId), amount, "Clawback balance of transferer");
        assertEq(clawback.balanceOf(address(this), result.wrappedTokenId), 0, "Clawback balance of owner");
    }

    function testTransferByTransfererNotApproved(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration,
        uint64 transferTimestamp,
        bool transferOpen,
        address transferer,
        address receiver,
        bool batch
    ) public safeAddress(receiver) {
        vm.assume(transferer != address(this));

        WrapSetupResult memory result =
            _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration, address(this));
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;

        clawback.updateTemplate(result.templateId, duration, false, transferOpen); // Doesn't matter
        clawback.addTemplateTransferer(result.templateId, transferer);

        vm.warp(transferTimestamp); // Doesn't matter if locked or unlocked

        if (batch) {
            uint256[] memory tokenIds = new uint256[](1);
            tokenIds[0] = result.wrappedTokenId;
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = amount;
            vm.expectRevert(ERC1155.NotOwnerNorApproved.selector);
            vm.prank(transferer);
            clawback.safeBatchTransferFrom(address(this), receiver, tokenIds, amounts, "");
        } else {
            vm.expectRevert(ERC1155.NotOwnerNorApproved.selector);
            vm.prank(transferer);
            clawback.safeTransferFrom(address(this), receiver, result.wrappedTokenId, amount, "");
        }
    }

    function testTransferInvalidOperator(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration,
        address operator,
        address receiver,
        bool batch
    ) public safeAddress(operator) {
        WrapSetupResult memory result =
            _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration, address(this));
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;

        clawback.updateTemplateOperator(result.templateId, operator, true); // Doesn't matter

        vm.expectRevert(Unauthorized.selector);
        vm.prank(operator);
        if (batch) {
            uint256[] memory tokenIds = new uint256[](1);
            tokenIds[0] = result.wrappedTokenId;
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = amount;
            clawback.safeBatchTransferFrom(address(this), receiver, tokenIds, amounts, "");
        } else {
            clawback.safeTransferFrom(address(this), receiver, result.wrappedTokenId, amount, "");
        }
    }

    //
    // Receiver prevention
    //
    function testPreventsOnERC721Received(
        uint256 tokenId
    ) public {
        (, tokenId,) = _validParams(IClawbackFunctions.TokenType.ERC721, tokenId, 1);
        erc721.mint(address(this), tokenId, 1);

        vm.expectRevert(InvalidReceiver.selector);
        erc721.safeTransferFrom(address(this), address(clawback), tokenId);
    }

    function testPreventsOnERC1155Received(uint256 tokenId, uint256 amount) public {
        (, tokenId, amount) = _validParams(IClawbackFunctions.TokenType.ERC1155, tokenId, amount);
        erc1155.mint(address(this), tokenId, amount);

        vm.expectRevert(InvalidReceiver.selector);
        erc1155.safeTransferFrom(address(this), address(clawback), tokenId, amount, "");
    }

    function testPreventsOnERC1155Received(
        uint256 tokenId1,
        uint256 amount1,
        uint256 tokenId2,
        uint256 amount2
    ) public {
        (, tokenId1, amount1) = _validParams(IClawbackFunctions.TokenType.ERC1155, tokenId1, amount1);
        (, tokenId2, amount2) = _validParams(IClawbackFunctions.TokenType.ERC1155, tokenId2, amount2);
        vm.assume(tokenId1 != tokenId2);
        erc1155.mint(address(this), tokenId1, amount1);
        erc1155.mint(address(this), tokenId2, amount2);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId1;
        tokenIds[1] = tokenId2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        vm.expectRevert(InvalidReceiver.selector);
        erc1155.safeBatchTransferFrom(address(this), address(clawback), tokenIds, amounts, "");
    }

    //
    // Supports Interface
    //
    function testSupportsInterface() public view {
        assertTrue(clawback.supportsInterface(type(IERC165).interfaceId));
        assertTrue(clawback.supportsInterface(type(IERC1155).interfaceId));
        assertTrue(clawback.supportsInterface(type(IClawbackFunctions).interfaceId));
        assertTrue(clawback.supportsInterface(type(ISignalsImplicitMode).interfaceId));
    }

}
