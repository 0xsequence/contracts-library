// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { TestHelper } from "../TestHelper.sol";
import { ERC1155Mock } from "../_mocks/ERC1155Mock.sol";
import { ERC1271Mock } from "../_mocks/ERC1271Mock.sol";
import { ERC20Mock } from "../_mocks/ERC20Mock.sol";
import { ERC721Mock } from "../_mocks/ERC721Mock.sol";
import { IGenericToken } from "../_mocks/IGenericToken.sol";

import { IPayments, IPaymentsFunctions, IPaymentsSignals } from "src/payments/IPayments.sol";
import { Payments } from "src/payments/Payments.sol";
import { PaymentsFactory } from "src/payments/PaymentsFactory.sol";

import { IERC165 } from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

contract PaymentsTest is TestHelper, IPaymentsSignals {

    Payments public payments;
    address public owner;
    address public signer;
    uint256 public signerPk;
    ERC1271Mock public signer1271;

    ERC20Mock public erc20;
    ERC721Mock public erc721;
    ERC1155Mock public erc1155;

    function setUp() public {
        owner = makeAddr("owner");
        (signer, signerPk) = makeAddrAndKey("signer");
        PaymentsFactory factory = new PaymentsFactory(owner);
        payments = Payments(factory.deploy(owner, owner, signer));

        erc20 = new ERC20Mock(address(this));
        erc721 = new ERC721Mock(address(this), "baseURI");
        erc1155 = new ERC1155Mock(address(this), "baseURI");

        signer1271 = new ERC1271Mock();
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

    function _toTokenType(
        uint8 tokenType
    ) internal pure returns (IPaymentsFunctions.TokenType) {
        tokenType = tokenType % 3;
        if (tokenType == 0) {
            return IPaymentsFunctions.TokenType.ERC20;
        }
        if (tokenType == 1) {
            return IPaymentsFunctions.TokenType.ERC721;
        }
        return IPaymentsFunctions.TokenType.ERC1155;
    }

    function _validTokenParams(
        IPaymentsFunctions.TokenType tokenType,
        uint256 tokenId,
        uint256 amount
    ) internal view returns (address, uint256, uint256) {
        // / 10 to avoid overflow when paying multiple
        if (tokenType == IPaymentsFunctions.TokenType.ERC20) {
            return (address(erc20), 0, bound(amount, 1, type(uint256).max / 10));
        }
        if (tokenType == IPaymentsFunctions.TokenType.ERC721) {
            return (address(erc721), bound(tokenId, 1, type(uint256).max / 10), 1);
        }
        return (address(erc1155), tokenId, bound(amount, 1, type(uint128).max / 10));
    }

    function _signPayment(
        IPaymentsFunctions.PaymentDetails memory details,
        bool isERC1271,
        bool isValid
    ) internal returns (bytes memory signature) {
        bytes32 digest = payments.hashPaymentDetails(details);
        return _signDigest(digest, isERC1271, isValid);
    }

    function _signChainedCall(
        IPaymentsFunctions.ChainedCallDetails memory details,
        bool isERC1271,
        bool isValid
    ) internal returns (bytes memory signature) {
        bytes32 digest = payments.hashChainedCallDetails(details);
        return _signDigest(digest, isERC1271, isValid);
    }

    function _signDigest(bytes32 digest, bool isERC1271, bool isValid) internal returns (bytes memory signature) {
        if (isERC1271) {
            vm.prank(owner);
            payments.updateSigner(address(signer1271));

            // Pretend digest is the signature
            if (isValid) {
                signer1271.setValidSignature(digest);
            }
            return abi.encodePacked(uint8(2), address(signer1271), digest);
        } else {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
            if (!isValid) {
                v--; // Invalidate sig
            }
            return abi.encodePacked(uint8(1), r, s, v);
        }
    }

    /**
     * Test all public selectors for collisions against the proxy admin functions.
     * @dev pnpm ts-node scripts/outputSelectors.ts
     */
    function testSelectorCollision() public pure {
        checkSelectorCollision(0x0e6fe11f); // hashChainedCallDetails((address,bytes))
        checkSelectorCollision(0x98c3065f); // hashPaymentDetails((uint256,address,uint8,address,uint256,(address,uint256)[],uint64,string,(address,bytes)))
        checkSelectorCollision(0x485cc955); // initialize(address,address)
        checkSelectorCollision(0x579a97e6); // isValidChainedCallSignature((address,bytes),bytes)
        checkSelectorCollision(0x7b8bdc8e); // isValidPaymentSignature((uint256,address,uint8,address,uint256,(address,uint256)[],uint64,string,(address,bytes)),bytes)
        checkSelectorCollision(0xdecfb3b2); // makePayment((uint256,address,uint8,address,uint256,(address,uint256)[],uint64,string,(address,bytes)),bytes)
        checkSelectorCollision(0x8da5cb5b); // owner()
        checkSelectorCollision(0x3a63b803); // paymentAccepted(uint256)
        checkSelectorCollision(0xb2238700); // performChainedCall((address,bytes),bytes)
        checkSelectorCollision(0x715018a6); // renounceOwnership()
        checkSelectorCollision(0x238ac933); // signer()
        checkSelectorCollision(0x01ffc9a7); // supportsInterface(bytes4)
        checkSelectorCollision(0xf2fde38b); // transferOwnership(address)
        checkSelectorCollision(0xa7ecd37e); // updateSigner(address)
    }

    function testMakePaymentSuccess(
        address caller,
        DetailsInput calldata input,
        bool isERC1271
    ) public safeAddress(caller) safeAddress(input.paymentRecipient.recipient) {
        uint64 expiration = uint64(_bound(input.expiration, block.timestamp, type(uint64).max));
        IPaymentsFunctions.TokenType tokenType = _toTokenType(input.tokenType);
        (address tokenAddr, uint256 tokenId, uint256 amount) =
            _validTokenParams(tokenType, input.tokenId, input.paymentRecipient.amount);
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
            IPaymentsFunctions.ChainedCallDetails(address(0), "")
        );

        // Mint required tokens
        IGenericToken(tokenAddr).mint(caller, tokenId, amount);
        IGenericToken(tokenAddr).approve(caller, address(payments), tokenId, amount);

        // Sign it
        bytes memory sig = _signPayment(details, isERC1271, true);

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

    function testMakePaymentSuccessChainedCall(
        address caller,
        DetailsInput calldata input,
        bool isERC1271
    ) public safeAddress(caller) safeAddress(input.paymentRecipient.recipient) safeAddress(input.productRecipient) {
        uint64 expiration = uint64(_bound(input.expiration, block.timestamp, type(uint64).max));
        IPaymentsFunctions.TokenType tokenType = _toTokenType(input.tokenType);
        (address tokenAddr, uint256 tokenId, uint256 amount) =
            _validTokenParams(tokenType, input.tokenId, input.paymentRecipient.amount);
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
        (address chainedTokenAddr, uint256 chainedTokenId, uint256 chainedAmount) =
            _validTokenParams(chainedTokenType, input.tokenId, input.paymentRecipient.amount);
        bytes memory chainedData =
            abi.encodeWithSelector(IGenericToken.mint.selector, input.productRecipient, chainedTokenId, chainedAmount);

        IPaymentsFunctions.PaymentDetails memory details = IPaymentsFunctions.PaymentDetails(
            input.purchaseId,
            input.productRecipient,
            tokenType,
            tokenAddr,
            tokenId,
            paymentRecipients,
            expiration,
            input.productId,
            IPaymentsFunctions.ChainedCallDetails(chainedTokenAddr, chainedData)
        );

        // Mint required tokens
        IGenericToken(tokenAddr).mint(caller, tokenId, amount);
        IGenericToken(tokenAddr).approve(caller, address(payments), tokenId, amount);

        // Sign it
        bytes memory sig = _signPayment(details, isERC1271, true);

        // Send it
        vm.expectEmit(true, true, true, true, address(payments));
        emit PaymentMade(caller, input.productRecipient, input.purchaseId, input.productId);
        vm.prank(caller);
        payments.makePayment(details, sig);

        assertEq(IGenericToken(tokenAddr).balanceOf(input.paymentRecipient.recipient, tokenId), amount);
        // Check chaining worked
        assertEq(IGenericToken(chainedTokenAddr).balanceOf(input.productRecipient, chainedTokenId), chainedAmount);
    }

    function testMakePaymentSuccessMultiplePaymentRecips(
        address caller,
        DetailsInput calldata input,
        address recip2,
        bool isERC1271
    ) public safeAddress(caller) safeAddress(input.paymentRecipient.recipient) safeAddress(recip2) {
        vm.assume(input.paymentRecipient.recipient != recip2);
        IPaymentsFunctions.TokenType tokenType = _toTokenType(input.tokenType);
        vm.assume(tokenType != IPaymentsFunctions.TokenType.ERC721); // ERC-721 not supported for multi payments

        uint64 expiration = uint64(_bound(input.expiration, block.timestamp, type(uint64).max));

        (address tokenAddr, uint256 tokenId, uint256 amount) =
            _validTokenParams(tokenType, input.tokenId, input.paymentRecipient.amount);
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
            IPaymentsFunctions.ChainedCallDetails(address(0), "")
        );

        // Mint required tokens
        IGenericToken(tokenAddr).mint(caller, tokenId, amount * 2);
        IGenericToken(tokenAddr).approve(caller, address(payments), tokenId, amount * 2);

        // Sign it
        bytes memory sig = _signPayment(details, isERC1271, true);

        // Send it
        vm.expectEmit(true, true, true, true, address(payments));
        emit PaymentMade(caller, input.productRecipient, input.purchaseId, input.productId);
        vm.prank(caller);
        payments.makePayment(details, sig);

        assertEq(IGenericToken(tokenAddr).balanceOf(input.paymentRecipient.recipient, tokenId), amount);
        assertEq(IGenericToken(tokenAddr).balanceOf(recip2, tokenId), amount);
    }

    function testMakePaymentInvalidSignature(address caller, DetailsInput calldata input, bool isERC1271) public {
        uint64 expiration = uint64(_bound(input.expiration, block.timestamp, type(uint64).max));
        IPaymentsFunctions.TokenType tokenType = _toTokenType(input.tokenType);
        (address tokenAddr, uint256 tokenId, uint256 amount) =
            _validTokenParams(tokenType, input.tokenId, input.paymentRecipient.amount);
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
            IPaymentsFunctions.ChainedCallDetails(address(0), "")
        );

        // Invalid sign it
        bytes memory sig = _signPayment(details, isERC1271, false);

        // Send it
        vm.expectRevert(InvalidSignature.selector);
        vm.prank(caller);
        payments.makePayment(details, sig);
    }

    function testMakePaymentExpired(
        address caller,
        DetailsInput calldata input,
        uint64 blockTimestamp,
        bool isERC1271
    ) public safeAddress(caller) safeAddress(input.paymentRecipient.recipient) {
        vm.assume(blockTimestamp > input.expiration);
        vm.warp(blockTimestamp);

        IPaymentsFunctions.TokenType tokenType = _toTokenType(input.tokenType);
        (address tokenAddr, uint256 tokenId, uint256 amount) =
            _validTokenParams(tokenType, input.tokenId, input.paymentRecipient.amount);
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
            IPaymentsFunctions.ChainedCallDetails(address(0), "")
        );

        // Mint required tokens
        IGenericToken(tokenAddr).mint(caller, tokenId, amount);
        IGenericToken(tokenAddr).approve(caller, address(payments), tokenId, amount);

        // Sign it
        bytes memory sig = _signPayment(details, isERC1271, true);

        // Send it
        vm.expectRevert(PaymentExpired.selector);
        vm.prank(caller);
        payments.makePayment(details, sig);
    }

    function testMakePaymentInvalidPayment(
        address caller,
        DetailsInput calldata input,
        bool isERC1271
    ) public safeAddress(caller) safeAddress(input.paymentRecipient.recipient) {
        uint64 expiration = uint64(_bound(input.expiration, block.timestamp, type(uint64).max));
        IPaymentsFunctions.TokenType tokenType = _toTokenType(input.tokenType);
        (address tokenAddr, uint256 tokenId, uint256 amount) =
            _validTokenParams(tokenType, input.tokenId, input.paymentRecipient.amount);
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
            IPaymentsFunctions.ChainedCallDetails(address(0), "")
        );

        // Do not mint required tokens

        // Sign it
        bytes memory sig = _signPayment(details, isERC1271, true);

        // Send it
        vm.expectRevert();
        vm.prank(caller);
        payments.makePayment(details, sig);
    }

    function testMakePaymentInvalidTokenSettingsERC20(
        address caller,
        DetailsInput calldata input,
        uint256 tokenId,
        bool isERC1271
    ) public safeAddress(caller) safeAddress(input.paymentRecipient.recipient) {
        tokenId = _bound(tokenId, 1, type(uint256).max); // Non-zero

        uint64 expiration = uint64(_bound(input.expiration, block.timestamp, type(uint64).max));
        IPaymentsFunctions.TokenType tokenType = IPaymentsFunctions.TokenType.ERC20;
        (address tokenAddr,, uint256 amount) = _validTokenParams(tokenType, tokenId, input.paymentRecipient.amount);
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
            IPaymentsFunctions.ChainedCallDetails(address(0), "")
        );

        // Sign it
        bytes memory sig = _signPayment(details, isERC1271, true);

        // Send it
        vm.expectRevert(InvalidTokenTransfer.selector);
        vm.prank(caller);
        payments.makePayment(details, sig);
    }

    function testMakePaymentInvalidTokenSettingsERC721(
        address caller,
        DetailsInput calldata input,
        bool isERC1271
    ) public safeAddress(caller) safeAddress(input.paymentRecipient.recipient) {
        uint64 expiration = uint64(_bound(input.expiration, block.timestamp, type(uint64).max));
        IPaymentsFunctions.TokenType tokenType = IPaymentsFunctions.TokenType.ERC721;
        (address tokenAddr, uint256 tokenId, uint256 amount) =
            _validTokenParams(tokenType, input.tokenId, input.paymentRecipient.amount);
        IPaymentsFunctions.PaymentRecipient[] memory paymentRecipients = new IPaymentsFunctions.PaymentRecipient[](1);
        paymentRecipients[0] = input.paymentRecipient;
        paymentRecipients[0].amount = _bound(amount, 2, type(uint256).max); // Invalid amount

        IPaymentsFunctions.PaymentDetails memory details = IPaymentsFunctions.PaymentDetails(
            input.purchaseId,
            input.productRecipient,
            tokenType,
            tokenAddr,
            tokenId,
            paymentRecipients,
            expiration,
            input.productId,
            IPaymentsFunctions.ChainedCallDetails(address(0), "")
        );

        // Sign it
        bytes memory sig = _signPayment(details, isERC1271, true);

        // Send it
        vm.expectRevert(InvalidTokenTransfer.selector);
        vm.prank(caller);
        payments.makePayment(details, sig);
    }

    function testMakePaymentFailedChainedCall(
        address caller,
        DetailsInput calldata input,
        bytes memory chainedCallData,
        bool isERC1271
    ) public safeAddress(caller) safeAddress(input.paymentRecipient.recipient) safeAddress(input.productRecipient) {
        // Check the call will fail
        (bool success,) = address(payments).call(chainedCallData);
        vm.assume(!success);

        uint64 expiration = uint64(_bound(input.expiration, block.timestamp, type(uint64).max));
        IPaymentsFunctions.TokenType tokenType = _toTokenType(input.tokenType);
        (address tokenAddr, uint256 tokenId, uint256 amount) =
            _validTokenParams(tokenType, input.tokenId, input.paymentRecipient.amount);
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
            IPaymentsFunctions.ChainedCallDetails(address(payments), chainedCallData)
        );

        // Mint required tokens
        IGenericToken(tokenAddr).mint(caller, tokenId, amount);
        IGenericToken(tokenAddr).approve(caller, address(payments), tokenId, amount);

        // Sign it
        bytes memory sig = _signPayment(details, isERC1271, true);

        // Send it
        vm.expectRevert(ChainedCallFailed.selector);
        vm.prank(caller);
        payments.makePayment(details, sig);
    }

    // Chained call

    function testPerformChainedCallSuccess(
        uint8 tokenTypeInt,
        uint256 tokenId,
        uint256 amount,
        address recipient,
        bool isERC1271
    ) public safeAddress(recipient) {
        IPaymentsFunctions.TokenType tokenType = _toTokenType(tokenTypeInt);
        address tokenAddr;
        (tokenAddr, tokenId, amount) = _validTokenParams(tokenType, tokenId, amount);

        bytes memory callData = abi.encodeWithSelector(IGenericToken.mint.selector, recipient, tokenId, amount);
        IPaymentsFunctions.ChainedCallDetails memory chainedCallDetails =
            IPaymentsFunctions.ChainedCallDetails(tokenAddr, callData);

        // Sign it
        bytes memory sig = _signChainedCall(chainedCallDetails, isERC1271, true);

        // Send it
        vm.prank(signer);
        payments.performChainedCall(chainedCallDetails, sig);

        assertEq(IGenericToken(tokenAddr).balanceOf(recipient, tokenId), amount);
    }

    function testPerformChainedCallInvalidSignature(
        address caller,
        uint8 tokenTypeInt,
        uint256 tokenId,
        uint256 amount,
        address recipient,
        bool isERC1271
    ) public safeAddress(recipient) {
        vm.assume(caller != signer);

        IPaymentsFunctions.TokenType tokenType = _toTokenType(tokenTypeInt);
        address tokenAddr;
        (tokenAddr, tokenId, amount) = _validTokenParams(tokenType, tokenId, amount);

        bytes memory callData = abi.encodeWithSelector(IGenericToken.mint.selector, recipient, tokenId, amount);
        IPaymentsFunctions.ChainedCallDetails memory chainedCallDetails =
            IPaymentsFunctions.ChainedCallDetails(tokenAddr, callData);

        // Fake sign it
        bytes memory sig = _signChainedCall(chainedCallDetails, isERC1271, false);

        // Send it
        vm.expectRevert(InvalidSignature.selector);
        vm.prank(caller);
        payments.performChainedCall(chainedCallDetails, sig);
    }

    function testPerformChainedCallInvalidCall(bytes calldata chainedCallData, bool isERC1271) public {
        IPaymentsFunctions.ChainedCallDetails memory chainedCallDetails =
            IPaymentsFunctions.ChainedCallDetails(address(this), chainedCallData);
        // Check the call will fail
        (bool success,) = chainedCallDetails.chainedCallAddress.call(chainedCallDetails.chainedCallData);
        vm.assume(!success);

        // Sign it
        bytes memory sig = _signChainedCall(chainedCallDetails, isERC1271, true);

        vm.expectRevert(ChainedCallFailed.selector);
        vm.prank(signer);
        payments.performChainedCall(chainedCallDetails, sig);
    }

    // Update signer

    function testUpdateSignerSuccess(
        address newSigner
    ) public {
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

    modifier safeAddress(
        address addr
    ) {
        vm.assume(addr != address(0));
        vm.assume(addr.code.length <= 2);
        assumeNotPrecompile(addr);
        assumeNotForgeAddress(addr);
        _;
    }

}
