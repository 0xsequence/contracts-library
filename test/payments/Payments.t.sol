// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import {Payments, IERC165} from "src/payments/Payments.sol";
import {IPayments, IPaymentsFunctions, IPaymentsSignals} from "src/payments/IPayments.sol";

import {ERC1155Mock} from "test/_mocks/ERC1155Mock.sol";
import {ERC20Mock} from "test/_mocks/ERC20Mock.sol";
import {ERC721Mock} from "test/_mocks/ERC721Mock.sol";
import {IGenericToken} from "test/_mocks/IGenericToken.sol";

contract PaymentsTest is Test, IPaymentsSignals {
    Payments public payments;
    address public owner;
    address public signer;
    uint256 public signerPk;

    ERC20Mock public erc20;
    ERC721Mock public erc721;
    ERC1155Mock public erc1155;

    function setUp() public {
        owner = makeAddr("owner");
        (signer, signerPk) = makeAddrAndKey("signer");
        payments = new Payments(owner, signer);

        erc20 = new ERC20Mock(address(this));
        erc721 = new ERC721Mock(address(this), "baseURI");
        erc1155 = new ERC1155Mock(address(this), "baseURI");
    }

    struct DetailsInput {
        uint256 purchaseId;
        address productRecipient;
        uint8 tokenType;
        address tokenAddress;
        uint256 tokenId;
        IPaymentsFunctions.PaymentRecipient paymentRecipient;
        uint64 expiration;
        string productId;
    }

    function _toTokenType(uint8 tokenType) internal pure returns (IPaymentsFunctions.TokenType) {
        tokenType = tokenType % 3;
        if (tokenType == 0) {
            return IPaymentsFunctions.TokenType.ERC20;
        }
        if (tokenType == 1) {
            return IPaymentsFunctions.TokenType.ERC721;
        }
        return IPaymentsFunctions.TokenType.ERC1155;
    }

    function _validTokenParams(IPaymentsFunctions.TokenType tokenType, uint256 tokenId, uint256 amount)
        internal
        view
        returns (address, uint256, uint256)
    {
        // / 10 to avoid overflow when paying multiple
        if (tokenType == IPaymentsFunctions.TokenType.ERC20) {
            return (address(erc20), 0, bound(amount, 1, type(uint256).max / 10));
        }
        if (tokenType == IPaymentsFunctions.TokenType.ERC721) {
            return (address(erc721), bound(tokenId, 1, type(uint256).max / 10), 1);
        }
        return (address(erc1155), tokenId, bound(amount, 1, type(uint128).max / 10));
    }

    function testMakePaymentSuccess(address caller, DetailsInput calldata input)
        public
        safeAddress(caller)
        safeAddress(input.paymentRecipient.recipient)
    {
        uint64 expiration = uint64(_bound(input.expiration, block.timestamp, type(uint64).max));
        IPaymentsFunctions.TokenType tokenType = _toTokenType(input.tokenType);
        (address tokenAddr, uint256 tokenId, uint256 amount) = _validTokenParams(tokenType, input.tokenId, input.paymentRecipient.amount);
        IPaymentsFunctions.PaymentRecipient[] memory paymentRecipients = new IPaymentsFunctions.PaymentRecipient[](1);
        paymentRecipients[0] = input.paymentRecipient;
        paymentRecipients[0].amount = amount;

        IPaymentsFunctions.PaymentDetails memory details = IPaymentsFunctions.PaymentDetails(
            input.purchaseId,
            input.productRecipient,
            tokenType,
            tokenAddr,
            tokenId,
            paymentRecipients,
            expiration,
            input.productId,
            address(0),
            ""
        );

        // Mint required tokens
        IGenericToken(tokenAddr).mint(caller, tokenId, amount);
        IGenericToken(tokenAddr).approve(caller, address(payments), tokenId, amount);

        // Sign it
        bytes32 messageHash = payments.hashPaymentDetails(details);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, messageHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        // Send it
        vm.expectEmit(true, true, true, true, address(payments));
        emit PaymentMade(caller, input.productRecipient, input.purchaseId, input.productId);
        vm.prank(caller);
        payments.makePayment(details, sig);

        assertEq(IGenericToken(tokenAddr).balanceOf(input.paymentRecipient.recipient, tokenId), amount);

        // Duplicate call fails
        vm.expectRevert(PaymentAlreadyAccepted.selector);
        vm.prank(caller);
        payments.makePayment(details, sig);
    }

    function testMakePaymentSuccessChainedCall(address caller, DetailsInput calldata input)
        public
        safeAddress(caller)
        safeAddress(input.paymentRecipient.recipient)
        safeAddress(input.productRecipient)
    {
        uint64 expiration = uint64(_bound(input.expiration, block.timestamp, type(uint64).max));
        IPaymentsFunctions.TokenType tokenType = _toTokenType(input.tokenType);
        (address tokenAddr, uint256 tokenId, uint256 amount) = _validTokenParams(tokenType, input.tokenId, input.paymentRecipient.amount);
        IPaymentsFunctions.PaymentRecipient[] memory paymentRecipients = new IPaymentsFunctions.PaymentRecipient[](1);
        paymentRecipients[0] = input.paymentRecipient;
        paymentRecipients[0].amount = amount;

        // Will mint the next token type
        IPaymentsFunctions.TokenType chainedTokenType;
        if (tokenType == IPaymentsFunctions.TokenType.ERC20) {
            chainedTokenType = IPaymentsFunctions.TokenType.ERC721;
        } else if (tokenType == IPaymentsFunctions.TokenType.ERC721) {
            chainedTokenType = IPaymentsFunctions.TokenType.ERC1155;
        } else {
            chainedTokenType = IPaymentsFunctions.TokenType.ERC20;
        }
        (address chainedTokenAddr, uint256 chainedTokenId, uint256 chainedAmount) = _validTokenParams(chainedTokenType, input.tokenId, input.paymentRecipient.amount);
        bytes memory chainedData = abi.encodeWithSelector(IGenericToken.mint.selector, input.productRecipient, chainedTokenId, chainedAmount);

        IPaymentsFunctions.PaymentDetails memory details = IPaymentsFunctions.PaymentDetails(
            input.purchaseId,
            input.productRecipient,
            tokenType,
            tokenAddr,
            tokenId,
            paymentRecipients,
            expiration,
            input.productId,
            chainedTokenAddr,
            chainedData
        );

        // Mint required tokens
        IGenericToken(tokenAddr).mint(caller, tokenId, amount);
        IGenericToken(tokenAddr).approve(caller, address(payments), tokenId, amount);

        // Sign it
        bytes32 messageHash = payments.hashPaymentDetails(details);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, messageHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        // Send it
        vm.expectEmit(true, true, true, true, address(payments));
        emit PaymentMade(caller, input.productRecipient, input.purchaseId, input.productId);
        vm.prank(caller);
        payments.makePayment(details, sig);

        assertEq(IGenericToken(tokenAddr).balanceOf(input.paymentRecipient.recipient, tokenId), amount);
        // Check chaining worked
        assertEq(IGenericToken(chainedTokenAddr).balanceOf(input.productRecipient, chainedTokenId), chainedAmount);
    }

    function testMakePaymentSuccessMultiplePaymentRecips(address caller, DetailsInput calldata input, address recip2)
        public
        safeAddress(caller)
        safeAddress(input.paymentRecipient.recipient)
        safeAddress(recip2)
    {
        vm.assume(input.paymentRecipient.recipient != recip2);
        IPaymentsFunctions.TokenType tokenType = _toTokenType(input.tokenType);
        vm.assume(tokenType != IPaymentsFunctions.TokenType.ERC721); // ERC-721 not supported for multi payments

        uint64 expiration = uint64(_bound(input.expiration, block.timestamp, type(uint64).max));

        (address tokenAddr, uint256 tokenId, uint256 amount) = _validTokenParams(tokenType, input.tokenId, input.paymentRecipient.amount);
        IPaymentsFunctions.PaymentRecipient[] memory paymentRecipients = new IPaymentsFunctions.PaymentRecipient[](2);
        paymentRecipients[0] = input.paymentRecipient;
        paymentRecipients[0].amount = amount;
        paymentRecipients[1] = IPaymentsFunctions.PaymentRecipient(recip2, amount);

        IPaymentsFunctions.PaymentDetails memory details = IPaymentsFunctions.PaymentDetails(
            input.purchaseId,
            input.productRecipient,
            tokenType,
            tokenAddr,
            tokenId,
            paymentRecipients,
            expiration,
            input.productId,
            address(0),
            ""
        );

        // Mint required tokens
        IGenericToken(tokenAddr).mint(caller, tokenId, amount * 2);
        IGenericToken(tokenAddr).approve(caller, address(payments), tokenId, amount * 2);

        // Sign it
        bytes32 messageHash = payments.hashPaymentDetails(details);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, messageHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        // Send it
        vm.expectEmit(true, true, true, true, address(payments));
        emit PaymentMade(caller, input.productRecipient, input.purchaseId, input.productId);
        vm.prank(caller);
        payments.makePayment(details, sig);

        assertEq(IGenericToken(tokenAddr).balanceOf(input.paymentRecipient.recipient, tokenId), amount);
        assertEq(IGenericToken(tokenAddr).balanceOf(recip2, tokenId), amount);
    }

    function testMakePaymentInvalidSignature(address caller, DetailsInput calldata input, bytes memory signature)
        public
    {
        uint64 expiration = uint64(_bound(input.expiration, block.timestamp, type(uint64).max));
        IPaymentsFunctions.TokenType tokenType = _toTokenType(input.tokenType);
        (address tokenAddr, uint256 tokenId, uint256 amount) = _validTokenParams(tokenType, input.tokenId, input.paymentRecipient.amount);
        IPaymentsFunctions.PaymentRecipient[] memory paymentRecipients = new IPaymentsFunctions.PaymentRecipient[](1);
        paymentRecipients[0] = input.paymentRecipient;
        paymentRecipients[0].amount = amount;

        IPaymentsFunctions.PaymentDetails memory details = IPaymentsFunctions.PaymentDetails(
            input.purchaseId,
            input.productRecipient,
            tokenType,
            tokenAddr,
            tokenId,
            paymentRecipients,
            expiration,
            input.productId,
            address(0),
            ""
        );

        // Send it
        vm.expectRevert(InvalidSignature.selector);
        vm.prank(caller);
        payments.makePayment(details, signature);
    }

    function testMakePaymentExpired(address caller, DetailsInput calldata input, uint64 blockTimestamp)
        public
        safeAddress(caller)
        safeAddress(input.paymentRecipient.recipient)
    {
        vm.assume(blockTimestamp > input.expiration);
        vm.warp(blockTimestamp);

        IPaymentsFunctions.TokenType tokenType = _toTokenType(input.tokenType);
        (address tokenAddr, uint256 tokenId, uint256 amount) = _validTokenParams(tokenType, input.tokenId, input.paymentRecipient.amount);
        IPaymentsFunctions.PaymentRecipient[] memory paymentRecipients = new IPaymentsFunctions.PaymentRecipient[](1);
        paymentRecipients[0] = input.paymentRecipient;
        paymentRecipients[0].amount = amount;

        IPaymentsFunctions.PaymentDetails memory details = IPaymentsFunctions.PaymentDetails(
            input.purchaseId,
            input.productRecipient,
            tokenType,
            tokenAddr,
            tokenId,
            paymentRecipients,
            input.expiration,
            input.productId,
            address(0),
            ""
        );

        // Mint required tokens
        IGenericToken(tokenAddr).mint(caller, tokenId, amount);
        IGenericToken(tokenAddr).approve(caller, address(payments), tokenId, amount);

        // Sign it
        bytes32 messageHash = payments.hashPaymentDetails(details);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, messageHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        // Send it
        vm.expectRevert(PaymentExpired.selector);
        vm.prank(caller);
        payments.makePayment(details, sig);
    }

    // Update signer

    function testUpdateSignerSuccess(address newSigner) public {
        vm.prank(owner);
        payments.updateSigner(newSigner);
        assertEq(payments.signer(), newSigner);
    }

    function testUpdateSignerInvalidSender(address caller, address newSigner) public {
        vm.assume(caller != owner);

        vm.expectRevert();
        vm.prank(caller);
        payments.updateSigner(newSigner);
    }

    // Supports interface

    function testSupportsInterface() public view {
        assertTrue(payments.supportsInterface(type(IPayments).interfaceId));
        assertTrue(payments.supportsInterface(type(IPaymentsFunctions).interfaceId));
        assertTrue(payments.supportsInterface(type(IERC165).interfaceId));
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
