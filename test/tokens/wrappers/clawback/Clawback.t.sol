// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Test, console, stdError} from "forge-std/Test.sol";
import {IERC721TokenReceiver} from "forge-std/interfaces/IERC721.sol";

import {Clawback} from "src/tokens/wrappers/clawback/Clawback.sol";
import {IClawback, IClawbackFunctions, IClawbackSignals} from "src/tokens/wrappers/clawback/IClawback.sol";

import {ERC1155Mock} from "test/_mocks/ERC1155Mock.sol";
import {ERC20Mock} from "test/_mocks/ERC20Mock.sol";
import {ERC721Mock} from "test/_mocks/ERC721Mock.sol";
import {IGenericToken} from "test/_mocks/IGenericToken.sol";

import {IERC1155TokenReceiver} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155TokenReceiver.sol";

import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {IERC1155Metadata} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155Metadata.sol";
import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";

contract ClawbackTest is Test, IClawbackSignals, IERC1155TokenReceiver, IERC721TokenReceiver {
    Clawback public clawback;
    ERC20Mock public erc20;
    ERC721Mock public erc721;
    ERC1155Mock public erc1155;

    function setUp() public {
        clawback = new Clawback("", "");
        erc20 = new ERC20Mock(address(this));
        erc721 = new ERC721Mock(address(this), "baseURI");
        erc1155 = new ERC1155Mock(address(this), "baseURI");
    }

    function _toTokenType(uint8 tokenType) internal pure returns (IClawbackFunctions.TokenType) {
        tokenType = tokenType % 3;
        if (tokenType == 0) {
            return IClawbackFunctions.TokenType.ERC20;
        }
        if (tokenType == 1) {
            return IClawbackFunctions.TokenType.ERC721;
        }
        return IClawbackFunctions.TokenType.ERC1155;
    }

    function _validParams(IClawbackFunctions.TokenType tokenType, uint256 tokenId, uint256 amount)
        internal
        view
        returns (address, uint256, uint256)
    {
        if (tokenType == IClawbackFunctions.TokenType.ERC20) {
            return (address(erc20), 0, bound(amount, 1, type(uint256).max));
        }
        if (tokenType == IClawbackFunctions.TokenType.ERC721) {
            return (address(erc721), bound(tokenId, 1, type(uint256).max), 1);
        }
        return (address(erc1155), tokenId, bound(amount, 1, type(uint128).max));
    }

    //
    // Template
    //
    function testAddTemplate(address admin, uint96 duration, bool destructionOnly, bool transferOpen)
        public
        returns (uint24 templateId)
    {
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
        uint96 durationA,
        bool destructionOnlyA,
        bool transferOpenA,
        uint96 durationB,
        bool destructionOnlyB,
        bool transferOpenB
    ) public {
        durationB = uint96(bound(durationB, 0, durationA));
        destructionOnlyB = destructionOnlyA || destructionOnlyB;
        transferOpenB = transferOpenA || transferOpenB;

        uint24 templateId = testAddTemplate(admin, durationA, destructionOnlyA, transferOpenA);

        vm.expectEmit(true, true, true, true, address(clawback));
        emit TemplateUpdated(templateId, durationB, destructionOnlyB, transferOpenB);
        vm.prank(admin);
        clawback.updateTemplate(templateId, durationB, destructionOnlyB, transferOpenB);
    }

    function testUpdateTemplateInvalidCaller(
        address admin,
        address nonAdmin,
        bool isNonAdminOperator,
        uint96 duration,
        bool destructionOnly,
        bool transferOpen
    ) public {
        vm.assume(admin != nonAdmin);

        uint24 templateId = testAddTemplate(admin, duration, destructionOnly, transferOpen);

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
        uint96 durationA,
        bool destructionOnly,
        bool transferOpen,
        uint96 durationB
    ) public {
        vm.assume(durationB > durationA);

        uint24 templateId = testAddTemplate(admin, durationA, destructionOnly, transferOpen);

        vm.expectRevert(abi.encodeWithSelector(InvalidTemplateChange.selector, "Duration must be equal or decrease"));
        vm.prank(admin);
        clawback.updateTemplate(templateId, durationB, destructionOnly, transferOpen);
    }

    function testUpdateTemplateInvalidDestructionOnly() public {
        // No reason to fuzz this
        uint24 templateId = testAddTemplate(address(this), 0, true, false);

        vm.expectRevert(abi.encodeWithSelector(InvalidTemplateChange.selector, "Cannot change from destruction only"));
        clawback.updateTemplate(templateId, 0, false, false);
    }

    function testUpdateTemplateInvalidTransferOpen() public {
        // No reason to fuzz this
        uint24 templateId = testAddTemplate(address(this), 0, false, true);

        vm.expectRevert(abi.encodeWithSelector(InvalidTemplateChange.selector, "Cannot change from transfer open"));
        clawback.updateTemplate(templateId, 0, false, false);
    }

    function testUpdateTemplateAdminInvalidCaller(address admin, address nonAdmin, bool isNonAdminOperator) public {
        vm.assume(admin != nonAdmin);
        uint24 templateId = testAddTemplate(admin, 0, false, true);

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
        uint24 templateId = testAddTemplate(address(this), 0, false, true);

        vm.expectRevert(abi.encodeWithSelector(InvalidTemplateChange.selector, "Admin cannot be zero address"));
        clawback.updateTemplateAdmin(templateId, address(0));
    }

    function testUpdateTemplateAdmin(
        address adminA,
        address adminB,
        uint96 duration,
        bool destructionOnly,
        bool transferOpen
    ) public safeAddress(adminA) safeAddress(adminB) {
        vm.assume(adminA != adminB);
        uint24 templateId = testAddTemplate(adminA, duration, destructionOnly, transferOpen);

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
        uint24 templateId = testAddTemplate(admin, 0, false, true);

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
        uint24 templateId = testAddTemplate(admin, 0, false, true);

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
        uint24 templateId = testAddTemplate(admin, 0, false, true);

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
        uint24 templateId = testAddTemplate(admin, 0, false, true);

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
    function testWrap(address templateAdmin, uint8 tokenTypeNum, uint256 tokenId, uint256 amount) public {
        IClawbackFunctions.TokenType tokenType = _toTokenType(tokenTypeNum);
        address tokenAddr;
        (tokenAddr, tokenId, amount) = _validParams(tokenType, tokenId, amount);

        IGenericToken(tokenAddr).mint(address(this), tokenId, amount);
        IGenericToken(tokenAddr).approve(address(this), address(clawback), tokenId, amount);

        uint24 templateId = testAddTemplate(templateAdmin, 1, false, false);

        vm.expectEmit(true, true, true, true, address(clawback));
        emit Wrapped(0, templateId, tokenAddr, tokenId, amount, address(this));
        clawback.wrap(templateId, tokenType, tokenAddr, tokenId, amount);

        assertEq(IGenericToken(tokenAddr).balanceOf(address(this), tokenId), 0);
        assertEq(IGenericToken(tokenAddr).balanceOf(address(clawback), tokenId), amount);
        IClawbackFunctions.TokenDetails memory details = clawback.getTokenDetails(0);
        assertEq(clawback.balanceOf(address(this), 0), amount);
        assertEq(details.templateId, templateId);
        assertEq(details.lockedAt, uint96(block.timestamp));
        assertEq(uint8(details.tokenType), uint8(tokenType));
        assertEq(details.tokenAddr, tokenAddr);
        assertEq(details.tokenId, tokenId);
    }

    // Note forge coverage misreports this as not covered
    function testWrapInvalidTokenType(address templateAdmin, uint8 tokenTypeNum, uint256 tokenId, uint256 amount)
        public
    {
        vm.assume(tokenTypeNum > 3);

        IClawbackFunctions.TokenType tokenType = _toTokenType(tokenTypeNum);
        address tokenAddr;
        (tokenAddr, tokenId, amount) = _validParams(tokenType, tokenId, amount);

        IGenericToken(tokenAddr).mint(address(this), tokenId, amount);
        IGenericToken(tokenAddr).approve(address(this), address(clawback), tokenId, amount);

        uint24 templateId = testAddTemplate(templateAdmin, 1, false, false);

        bytes memory data = abi.encodeWithSelector(
            IClawbackFunctions.wrap.selector, templateId, tokenTypeNum, tokenAddr, tokenId, amount
        );
        vm.expectRevert(InvalidTokenTransfer.selector);
        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = address(clawback).call(data);

        assertFalse(success);
    }

    function testWrapInvalidAmount(address templateAdmin, uint8 tokenTypeNum, uint256 tokenId, uint256 amount) public {
        IClawbackFunctions.TokenType tokenType = _toTokenType(tokenTypeNum);
        address tokenAddr;
        (tokenAddr, tokenId, amount) = _validParams(tokenType, tokenId, amount);

        IGenericToken(tokenAddr).mint(address(this), tokenId, amount);
        IGenericToken(tokenAddr).approve(address(this), address(clawback), tokenId, amount);

        uint24 templateId = testAddTemplate(templateAdmin, 1, false, false);

        if (tokenAddr == address(erc20) && tokenTypeNum % 2 == 0) {
            // Sometimes flip tokenId
            tokenId = 1;
        }
        amount = 0;

        vm.expectRevert(InvalidTokenTransfer.selector);
        clawback.wrap(templateId, tokenType, tokenAddr, tokenId, amount);
    }

    function testWrapInvalidTemplate(uint24 templateId, uint8 tokenTypeNum, uint256 tokenId, uint256 amount) public {
        IClawbackFunctions.TokenType tokenType = _toTokenType(tokenTypeNum);
        address tokenAddr;
        (tokenAddr, tokenId, amount) = _validParams(tokenType, tokenId, amount);

        IGenericToken(tokenAddr).mint(address(this), tokenId, amount);
        IGenericToken(tokenAddr).approve(address(this), address(clawback), tokenId, amount);

        vm.expectRevert(InvalidTemplate.selector);
        clawback.wrap(templateId, tokenType, tokenAddr, tokenId, amount);
    }

    //
    // Unwrap
    //
    struct WrapSetupResult {
        uint256 tokenId;
        uint256 amount;
        uint96 duration;
        address tokenAddr;
        uint24 templateId;
        uint256 wrappedTokenId;
    }

    function _wrapSetup(address templateAdmin, uint8 tokenTypeNum, uint256 tokenId, uint256 amount, uint96 duration)
        internal
        returns (WrapSetupResult memory result)
    {
        // Unwrap timestamp is uint64 as per ERC721A implmentation used by ERC721Mock
        result.duration = uint96(bound(duration, 1, type(uint64).max - block.timestamp));
        result.templateId = testAddTemplate(templateAdmin, result.duration, false, false);

        IClawbackFunctions.TokenType tokenType = _toTokenType(tokenTypeNum);
        (result.tokenAddr, result.tokenId, result.amount) = _validParams(tokenType, tokenId, amount);

        IGenericToken(result.tokenAddr).mint(address(this), result.tokenId, result.amount);
        IGenericToken(result.tokenAddr).approve(address(this), address(clawback), result.tokenId, result.amount);

        result.wrappedTokenId =
            clawback.wrap(result.templateId, tokenType, result.tokenAddr, result.tokenId, result.amount);

        // struct here prevents stack too deep during coverage reporting
        return result;
    }

    function testUnwrap(
        address templateAdmin,
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint96 duration,
        uint64 unwrapTimestamp
    ) public {
        WrapSetupResult memory result = _wrapSetup(templateAdmin, tokenTypeNum, tokenId, amount, duration);
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
        uint96 duration,
        uint64 unwrapTimestamp,
        address tokenOwner
    ) public safeAddress(tokenOwner) {
        WrapSetupResult memory result = _wrapSetup(templateAdmin, tokenTypeNum, tokenId, amount, duration);
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
        uint96 duration
    ) public {
        vm.assume(wrongWrappedTokenId != 0);
        WrapSetupResult memory result = _wrapSetup(templateAdmin, tokenTypeNum, tokenId, amount, duration);
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;
        vm.assume(wrongWrappedTokenId != result.wrappedTokenId);

        vm.warp(block.timestamp + duration);
        vm.expectRevert(stdError.arithmeticError);
        clawback.unwrap(wrongWrappedTokenId, address(this), amount);
    }

    function testUnwrapTokenLocked(
        address templateAdmin,
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint96 duration
    ) public {
        WrapSetupResult memory result = _wrapSetup(templateAdmin, tokenTypeNum, tokenId, amount, duration);
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
        uint96 duration
    ) public {
        WrapSetupResult memory result = _wrapSetup(templateAdmin, tokenTypeNum, tokenId, amount, duration);
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;
        vm.assume(amount != type(uint256).max);
        invalidAmount = bound(invalidAmount, amount + 1, type(uint256).max);

        vm.warp(block.timestamp + duration);
        vm.expectRevert(stdError.arithmeticError);
        clawback.unwrap(result.wrappedTokenId, address(this), invalidAmount);
    }

    function testUnwrapByOperator(
        address templateAdmin,
        address operator,
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint96 duration,
        uint64 unwrapTimestamp
    ) public {
        vm.assume(operator != address(this));

        WrapSetupResult memory result = _wrapSetup(templateAdmin, tokenTypeNum, tokenId, amount, duration);
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
        uint96 duration
    ) public {
        vm.assume(operator != address(this));

        WrapSetupResult memory result = _wrapSetup(templateAdmin, tokenTypeNum, tokenId, amount, duration);
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
        uint96 duration,
        address operator,
        address receiver
    ) public safeAddress(receiver) {
        WrapSetupResult memory result = _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration);
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
        assertEq(clawback.balanceOf(address(clawback), result.wrappedTokenId), 0, "Clawback balance of clawback"); // Burned
    }

    function testClawbackAfterTransfer(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint96 duration,
        address operator,
        address tokenOwner,
        address receiver
    ) public safeAddress(receiver) safeAddress(tokenOwner) {
        vm.assume(receiver != tokenOwner);

        WrapSetupResult memory result = _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration);
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

        assertEq(IGenericToken(result.tokenAddr).balanceOf(receiver, tokenId), amount, "Token balance of receiver");
        assertEq(IGenericToken(result.tokenAddr).balanceOf(address(this), tokenId), 0, "Token balance of owner");
        assertEq(IGenericToken(result.tokenAddr).balanceOf(address(clawback), tokenId), 0, "Token balance of clawback");
        assertEq(clawback.balanceOf(receiver, result.wrappedTokenId), 0, "Clawback balance of receiver");
        assertEq(clawback.balanceOf(address(this), result.wrappedTokenId), 0, "Clawback balance of owner");
        assertEq(clawback.balanceOf(address(clawback), result.wrappedTokenId), 0, "Clawback balance of clawback"); // Burned
    }

    function testClawbackInvalidUnlocked(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint96 duration,
        address operator,
        address receiver
    ) public safeAddress(receiver) {
        WrapSetupResult memory result = _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration);
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
        uint96 duration,
        address operator
    ) public {
        WrapSetupResult memory result = _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration);
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;

        clawback.updateTemplate(result.templateId, duration, true, false);
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
            address(0)
        );
        vm.prank(operator);
        clawback.clawback(result.wrappedTokenId, address(this), address(0), amount);

        address altBurnAddress = clawback.ALTERNATIVE_BURN_ADDRESS();
        uint256 burnAddressBalance = IGenericToken(result.tokenAddr).balanceOf(address(0), tokenId)
            | IGenericToken(result.tokenAddr).balanceOf(altBurnAddress, tokenId);
        assertEq(burnAddressBalance, amount, "Token balance of burn");
        assertEq(IGenericToken(result.tokenAddr).balanceOf(address(this), tokenId), 0, "Token balance of owner");
        assertEq(IGenericToken(result.tokenAddr).balanceOf(address(clawback), tokenId), 0, "Token balance of clawback");
        assertEq(clawback.balanceOf(address(0), result.wrappedTokenId), 0, "Clawback balance of address(0)"); // Burned
        assertEq(clawback.balanceOf(altBurnAddress, result.wrappedTokenId), 0, "Clawback balance of alt burn"); // Burned
            // not sent
            // here
        assertEq(clawback.balanceOf(address(this), result.wrappedTokenId), 0, "Clawback balance of owner");
        assertEq(clawback.balanceOf(address(clawback), result.wrappedTokenId), 0, "Clawback balance of clawback"); // Burned
    }

    function testClawbackDestructionOnlyInvalidReceiver(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint96 duration,
        address operator,
        address receiver
    ) public safeAddress(receiver) {
        WrapSetupResult memory result = _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration);
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
        uint96 duration,
        address operator,
        address receiver
    ) public {
        WrapSetupResult memory result = _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration);
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;

        vm.expectRevert(Unauthorized.selector);
        vm.prank(operator);
        clawback.clawback(result.wrappedTokenId, address(this), receiver, amount);
    }

    //
    // Transfer
    //
    function testTransferOpen(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint96 duration,
        uint64 transferTimestamp,
        address receiver
    ) public safeAddress(receiver) {
        WrapSetupResult memory result = _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration);
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;

        clawback.updateTemplate(result.templateId, duration, false, true);

        vm.warp(transferTimestamp); // Doesn't matter if locked or unlocked

        clawback.safeTransferFrom(address(this), receiver, result.wrappedTokenId, amount, "");

        assertEq(clawback.balanceOf(receiver, result.wrappedTokenId), amount, "Clawback balance of receiver");
        assertEq(clawback.balanceOf(address(this), result.wrappedTokenId), 0, "Clawback balance of owner");
    }

    function testTransferByTransferer(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint96 duration,
        uint64 transferTimestamp,
        bool transferOpen,
        address transferer,
        address receiver,
        bool batch
    ) public safeAddress(receiver) {
        WrapSetupResult memory result = _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration);
        tokenId = result.tokenId;
        amount = result.amount;
        duration = result.duration;

        clawback.updateTemplate(result.templateId, duration, false, transferOpen); // Doesn't matter
        clawback.addTemplateTransferer(result.templateId, transferer);

        // Approval still required
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

    function testTransferByTransfererNotApproved(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint96 duration,
        uint64 transferTimestamp,
        bool transferOpen,
        address transferer,
        address receiver,
        bool batch
    ) public safeAddress(receiver) {
        WrapSetupResult memory result = _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration);
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
            vm.expectRevert("ERC1155#safeBatchTransferFrom: INVALID_OPERATOR");
            vm.prank(transferer);
            clawback.safeBatchTransferFrom(address(this), receiver, tokenIds, amounts, "");
        } else {
            vm.expectRevert("ERC1155#safeTransferFrom: INVALID_OPERATOR");
            vm.prank(transferer);
            clawback.safeTransferFrom(address(this), receiver, result.wrappedTokenId, amount, "");
        }
    }

    function testTransferInvalidOperator(
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint96 duration,
        address operator,
        address receiver,
        bool batch
    ) public safeAddress(operator) {
        WrapSetupResult memory result = _wrapSetup(address(this), tokenTypeNum, tokenId, amount, duration);
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
    function testPreventsOnERC721Received(uint256 tokenId) public {
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

    function testPreventsOnERC1155Received(uint256 tokenId1, uint256 amount1, uint256 tokenId2, uint256 amount2)
        public
    {
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
        assertTrue(clawback.supportsInterface(type(IClawback).interfaceId));
        assertTrue(clawback.supportsInterface(type(IClawbackFunctions).interfaceId));
        assertTrue(clawback.supportsInterface(type(IERC1155).interfaceId));
        assertTrue(clawback.supportsInterface(type(IERC1155Metadata).interfaceId));
        assertTrue(clawback.supportsInterface(type(IERC165).interfaceId));
    }

    // Receiver

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    // Helper

    modifier safeAddress(address addr) {
        vm.assume(addr != address(0));
        vm.assume(addr.code.length <= 2);
        assumeNotPrecompile(addr);
        assumeNotForgeAddress(addr);
        _;
    }
}
