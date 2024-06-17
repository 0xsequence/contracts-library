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
        uint256 amount;
        address fundsRecipient;
        uint64 expiration;
        string productId;
        bytes additionalData;
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
        if (tokenType == IPaymentsFunctions.TokenType.ERC20) {
            return (address(erc20), 0, bound(amount, 1, type(uint256).max));
        }
        if (tokenType == IPaymentsFunctions.TokenType.ERC721) {
            return (address(erc721), bound(tokenId, 1, type(uint256).max), 1);
        }
        return (address(erc1155), tokenId, bound(amount, 1, type(uint128).max));
    }

    function testMakePaymentSuccess(address caller, DetailsInput calldata input)
        public
        safeAddress(caller)
        safeAddress(input.fundsRecipient)
    {
        IPaymentsFunctions.TokenType tokenType = _toTokenType(input.tokenType);
        (address tokenAddr, uint256 tokenId, uint256 amount) = _validTokenParams(tokenType, input.tokenId, input.amount);
        uint64 expiration = uint64(_bound(input.expiration, block.timestamp, type(uint64).max));
        IPaymentsFunctions.PaymentDetails memory details = IPaymentsFunctions.PaymentDetails(
            input.purchaseId,
            input.productRecipient,
            tokenType,
            tokenAddr,
            tokenId,
            amount,
            input.fundsRecipient,
            expiration,
            input.productId,
            input.additionalData
        );

        // Mint required tokens
        IGenericToken(tokenAddr).mint(caller, tokenId, amount);
        IGenericToken(tokenAddr).approve(caller, address(payments), tokenId, amount);

        // Sign it
        bytes32 messageHash = _hashPaymentDetails(details);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, messageHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        // Send it
        vm.expectEmit(true, true, true, true, address(payments));
        emit PaymentMade(caller, input.productRecipient, input.purchaseId, input.productId);
        vm.prank(caller);
        payments.makePayment(details, sig);

        assertEq(IGenericToken(tokenAddr).balanceOf(input.fundsRecipient, tokenId), amount);

        // Duplicate call fails
        vm.expectRevert(PaymentAlreadyAccepted.selector);
        vm.prank(caller);
        payments.makePayment(details, sig);
    }

    function testMakePaymentInvalidSignature(address caller, DetailsInput calldata input, bytes memory signature)
        public
    {
        IPaymentsFunctions.TokenType tokenType = _toTokenType(input.tokenType);
        (address tokenAddr, uint256 tokenId, uint256 amount) = _validTokenParams(tokenType, input.tokenId, input.amount);
        uint64 expiration = uint64(_bound(input.expiration, block.timestamp, type(uint64).max));
        IPaymentsFunctions.PaymentDetails memory details = IPaymentsFunctions.PaymentDetails(
            input.purchaseId,
            input.productRecipient,
            tokenType,
            tokenAddr,
            tokenId,
            amount,
            input.fundsRecipient,
            expiration,
            input.productId,
            input.additionalData
        );

        // Send it
        vm.expectRevert(InvalidSignature.selector);
        vm.prank(caller);
        payments.makePayment(details, signature);
    }

    function testMakePaymentExpired(address caller, DetailsInput calldata input, uint64 expiration, uint64 blockTimestamp)
        public
        safeAddress(caller)
        safeAddress(input.fundsRecipient)
    {
        vm.assume(blockTimestamp > expiration);
        vm.warp(blockTimestamp);

        IPaymentsFunctions.TokenType tokenType = _toTokenType(input.tokenType);
        (address tokenAddr, uint256 tokenId, uint256 amount) = _validTokenParams(tokenType, input.tokenId, input.amount);
        IPaymentsFunctions.PaymentDetails memory details = IPaymentsFunctions.PaymentDetails(
            input.purchaseId,
            input.productRecipient,
            tokenType,
            tokenAddr,
            tokenId,
            amount,
            input.fundsRecipient,
            expiration,
            input.productId,
            input.additionalData
        );

        // Mint required tokens
        IGenericToken(tokenAddr).mint(caller, tokenId, amount);
        IGenericToken(tokenAddr).approve(caller, address(payments), tokenId, amount);

        // Sign it
        bytes32 messageHash = _hashPaymentDetails(details);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, messageHash);
        bytes memory sig = abi.encodePacked(r, s, v);

        // Send it
        vm.expectRevert(PaymentExpired.selector);
        vm.prank(caller);
        payments.makePayment(details, sig);
    }

    function _hashPaymentDetails(IPaymentsFunctions.PaymentDetails memory details) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                details.purchaseId,
                details.productRecipient,
                details.tokenType,
                details.tokenAddress,
                details.tokenId,
                details.amount,
                details.fundsRecipient,
                details.expiration,
                details.productId,
                details.additionalData
            )
        );
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
