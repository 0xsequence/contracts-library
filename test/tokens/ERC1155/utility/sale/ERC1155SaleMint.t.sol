// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { console } from "forge-std/console.sol";

import { TestHelper } from "../../../../TestHelper.sol";
import { ERC20Mock } from "../../../../_mocks/ERC20Mock.sol";

import { IERC1155SupplySignals } from "src/tokens/ERC1155/extensions/supply/IERC1155Supply.sol";
import { ERC1155Items } from "src/tokens/ERC1155/presets/items/ERC1155Items.sol";
import { ERC1155Sale } from "src/tokens/ERC1155/utility/sale/ERC1155Sale.sol";
import { ERC1155SaleFactory } from "src/tokens/ERC1155/utility/sale/ERC1155SaleFactory.sol";
import { IERC1155Sale } from "src/tokens/ERC1155/utility/sale/IERC1155Sale.sol";
import { IMerkleProofSingleUseSignals } from "src/tokens/common/IMerkleProofSingleUse.sol";

// solhint-disable not-rely-on-time

contract ERC1155SaleMintTest is TestHelper, IERC1155SupplySignals, IMerkleProofSingleUseSignals {

    // Redeclare events
    event TransferSingle(
        address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _amount
    );
    event TransferBatch(
        address indexed _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _amounts
    );

    ERC1155Items private token;
    ERC1155Sale private sale;
    ERC20Mock private erc20;

    function setUp() public {
        token = new ERC1155Items();
        token.initialize(address(this), "test", "ipfs://", "ipfs://", address(this), 0, address(0), bytes32(0));

        sale = new ERC1155Sale();
        sale.initialize(address(this), address(token), address(0), bytes32(0));

        token.grantRole(keccak256("MINTER_ROLE"), address(sale));

        erc20 = new ERC20Mock(address(this));
    }

    function setUpFromFactory() public {
        ERC1155SaleFactory factory = new ERC1155SaleFactory(address(this));
        sale = ERC1155Sale(factory.deploy(0, address(this), address(this), address(token), address(0), bytes32(0)));
        token.grantRole(keccak256("MINTER_ROLE"), address(sale));
    }

    //
    // Minting
    //
    function test_mint_fail_invalidArrayLength(uint256[] memory array1, uint256[] memory array2) public {
        vm.assume(array1.length != array2.length);
        bytes32[][] memory proofs = new bytes32[][](array1.length);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Sale.InvalidArrayLengths.selector));
        sale.mint(address(0), array1, array1, "", array2, address(0), 0, proofs);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Sale.InvalidArrayLengths.selector));
        sale.mint(address(0), array1, array2, "", array1, address(0), 0, proofs);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Sale.InvalidArrayLengths.selector));
        sale.mint(address(0), array2, array1, "", array1, address(0), 0, proofs);
    }

    function test_mint_fail_invalidProofsArrayLength(uint256[] memory array1, bytes32[][] memory proofs) public {
        vm.assume(array1.length != proofs.length);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Sale.InvalidArrayLengths.selector));
        sale.mint(address(0), array1, array1, "", array1, address(0), 0, proofs);
    }

    function test_mint_fail_noSale(uint256 tokenId, uint256 amount) public {
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256[] memory saleIndexes = TestHelper.singleToArray(0);
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = TestHelper.blankProof();
        vm.expectRevert(abi.encodeWithSelector(IERC1155Sale.SaleDetailsNotFound.selector, 0));
        sale.mint(address(0), tokenIds, amounts, "", saleIndexes, address(0), 0, proofs);
    }

    function test_mint_success(
        bool useFactory,
        address recipient,
        IERC1155Sale.SaleDetails memory details,
        uint256 tokenId,
        uint256 amount
    ) public withFactory(useFactory) returns (uint256 saleIndex) {
        assumeSafeAddress(recipient);
        details = validSaleDetails(tokenId, details);
        saleIndex = sale.addSaleDetails(details);
        amount = bound(amount, 1, details.supply);
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256[] memory saleIndexes = TestHelper.singleToArray(saleIndex);
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = TestHelper.blankProof();

        uint256 expectedCost = details.cost * amount;
        vm.deal(address(this), expectedCost);

        vm.expectEmit(true, true, true, true, address(token));
        emit TransferBatch(address(sale), address(0), recipient, tokenIds, amounts);
        vm.expectEmit(true, true, true, true, address(sale));
        emit IERC1155Sale.ItemsMinted(recipient, tokenIds, amounts, saleIndexes);
        sale.mint{ value: expectedCost }(
            recipient, tokenIds, amounts, "", saleIndexes, address(0), expectedCost, proofs
        );

        assertEq(address(sale).balance, expectedCost);

        return saleIndex;
    }

    function test_mint_successERC20(
        bool useFactory,
        address recipient,
        IERC1155Sale.SaleDetails memory details,
        uint256 tokenId,
        uint256 amount
    ) public withFactory(useFactory) returns (uint256 saleIndex) {
        assumeSafeAddress(recipient);
        details = validSaleDetails(tokenId, details);
        details.paymentToken = address(erc20);
        saleIndex = sale.addSaleDetails(details);
        amount = bound(amount, 1, details.supply);
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256[] memory saleIndexes = TestHelper.singleToArray(saleIndex);
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = TestHelper.blankProof();

        uint256 expectedCost = details.cost * amount;
        erc20.mint(address(this), expectedCost);
        erc20.approve(address(sale), expectedCost);

        vm.expectEmit(true, true, true, true, address(token));
        emit TransferBatch(address(sale), address(0), recipient, tokenIds, amounts);
        vm.expectEmit(true, true, true, true, address(sale));
        emit IERC1155Sale.ItemsMinted(recipient, tokenIds, amounts, saleIndexes);
        sale.mint(recipient, tokenIds, amounts, "", saleIndexes, address(erc20), expectedCost, proofs);

        assertEq(erc20.balanceOf(address(this)), 0);
        assertEq(erc20.balanceOf(address(sale)), expectedCost);

        return saleIndex;
    }

    function test_mint_success_proof(
        bool useFactory,
        address recipient,
        IERC1155Sale.SaleDetails memory details,
        uint256 tokenId,
        uint256 amount,
        address[] memory allowlist,
        uint256 leafIndex
    ) public withFactory(useFactory) {
        assumeSafeAddress(recipient);
        details = validSaleDetails(tokenId, details);

        vm.assume(allowlist.length > 1);
        leafIndex = bound(leafIndex, 0, allowlist.length - 1);

        address sender = allowlist[leafIndex];

        bytes32[][] memory proofs = new bytes32[][](1);
        (details.merkleRoot, proofs[0]) = TestHelper.getMerkleParts(allowlist, tokenId, leafIndex);

        uint256 saleIndex = sale.addSaleDetails(details);
        amount = bound(amount, 1, details.supply);
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256[] memory saleIndexes = TestHelper.singleToArray(saleIndex);

        uint256 expectedCost = details.cost * amount;
        vm.deal(sender, expectedCost);

        vm.expectEmit(true, true, true, true, address(token));
        emit TransferBatch(address(sale), address(0), recipient, tokenIds, amounts);
        vm.expectEmit(true, true, true, true, address(sale));
        emit IERC1155Sale.ItemsMinted(recipient, tokenIds, amounts, saleIndexes);
        vm.prank(sender);
        sale.mint{ value: expectedCost }(
            recipient, tokenIds, amounts, "", saleIndexes, address(0), expectedCost, proofs
        );

        assertEq(address(sale).balance, expectedCost);
    }

    function test_mint_fail_invalidTokenId(
        bool useFactory,
        address recipient,
        IERC1155Sale.SaleDetails memory details,
        uint256 tokenId,
        uint256 amount,
        bool tokenIdAboveMax
    ) public withFactory(useFactory) {
        details = validSaleDetails(tokenId, details);
        if (tokenIdAboveMax) {
            vm.assume(details.maxTokenId < type(uint256).max);
            tokenId = bound(tokenId, details.maxTokenId + 1, type(uint256).max);
        } else {
            vm.assume(details.minTokenId > 0);
            tokenId = bound(tokenId, 0, details.minTokenId - 1);
        }

        uint256 saleIndex = sale.addSaleDetails(details);
        amount = bound(amount, 1, details.supply);
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256[] memory saleIndexes = TestHelper.singleToArray(saleIndex);
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = TestHelper.blankProof();

        uint256 expectedCost = details.cost * amount;
        vm.deal(address(this), expectedCost);

        vm.expectRevert(abi.encodeWithSelector(IERC1155Sale.InvalidSaleDetails.selector));
        sale.mint{ value: expectedCost }(
            recipient, tokenIds, amounts, "", saleIndexes, address(0), expectedCost, proofs
        );
    }

    function test_mint_successERC20_higherExpectedCost(
        bool useFactory,
        address recipient,
        IERC1155Sale.SaleDetails memory details,
        uint256 tokenId,
        uint256 amount,
        uint256 expectedCost
    ) public withFactory(useFactory) returns (uint256 saleIndex) {
        assumeSafeAddress(recipient);
        details = validSaleDetails(tokenId, details);
        details.paymentToken = address(erc20);
        saleIndex = sale.addSaleDetails(details);
        amount = bound(amount, 1, details.supply);
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256[] memory saleIndexes = TestHelper.singleToArray(saleIndex);
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = TestHelper.blankProof();

        uint256 realExpectedCost = details.cost * amount;
        expectedCost = bound(expectedCost, realExpectedCost, type(uint256).max);
        erc20.mint(address(this), expectedCost);
        erc20.approve(address(sale), expectedCost);

        vm.expectEmit(true, true, true, true, address(token));
        emit TransferBatch(address(sale), address(0), recipient, tokenIds, amounts);
        vm.expectEmit(true, true, true, true, address(sale));
        emit IERC1155Sale.ItemsMinted(recipient, tokenIds, amounts, saleIndexes);
        sale.mint(recipient, tokenIds, amounts, "", saleIndexes, address(erc20), expectedCost, proofs);

        assertEq(erc20.balanceOf(address(this)), expectedCost - realExpectedCost);
        assertEq(erc20.balanceOf(address(sale)), realExpectedCost);

        return saleIndex;
    }

    function test_mint_fail_beforeSale(
        bool useFactory,
        address recipient,
        IERC1155Sale.SaleDetails memory details,
        uint256 tokenId,
        uint256 amount,
        uint256 blockTime
    ) public withFactory(useFactory) {
        details = validSaleDetails(tokenId, details);
        blockTime = bound(blockTime, 0, type(uint64).max - 1);
        details.startTime = uint64(bound(details.startTime, blockTime + 1, type(uint64).max));
        details.endTime = uint64(bound(details.endTime, details.startTime, type(uint64).max));
        vm.warp(blockTime);

        uint256 saleIndex = sale.addSaleDetails(details);
        amount = bound(amount, 1, details.supply);
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256[] memory saleIndexes = TestHelper.singleToArray(saleIndex);
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = TestHelper.blankProof();

        vm.expectRevert(abi.encodeWithSelector(IERC1155Sale.SaleInactive.selector));
        sale.mint(recipient, tokenIds, amounts, "", saleIndexes, address(0), 0, proofs);
    }

    function test_mint_fail_afterSale(
        bool useFactory,
        address recipient,
        IERC1155Sale.SaleDetails memory details,
        uint256 tokenId,
        uint256 amount,
        uint256 blockTime
    ) public withFactory(useFactory) {
        details = validSaleDetails(tokenId, details);
        blockTime = bound(blockTime, 1, type(uint64).max);
        details.endTime = uint64(bound(details.endTime, 0, blockTime - 1));
        details.startTime = uint64(bound(details.startTime, 0, details.endTime));
        vm.warp(blockTime);

        uint256 saleIndex = sale.addSaleDetails(details);
        amount = bound(amount, 1, details.supply);
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256[] memory saleIndexes = TestHelper.singleToArray(saleIndex);
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = TestHelper.blankProof();

        vm.expectRevert(abi.encodeWithSelector(IERC1155Sale.SaleInactive.selector));
        sale.mint(recipient, tokenIds, amounts, "", saleIndexes, address(0), 0, proofs);
    }

    function test_mint_fail_supplyExceeded(
        bool useFactory,
        address recipient,
        IERC1155Sale.SaleDetails memory details,
        uint256 tokenId,
        uint256 amount
    ) public withFactory(useFactory) {
        details = validSaleDetails(tokenId, details);
        details.supply = bound(details.supply, 1, type(uint256).max - 1);

        uint256 saleIndex = sale.addSaleDetails(details);
        amount = bound(amount, details.supply + 1, type(uint256).max);
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256[] memory saleIndexes = TestHelper.singleToArray(saleIndex);
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = TestHelper.blankProof();

        vm.expectRevert(abi.encodeWithSelector(IERC1155Sale.InsufficientSupply.selector, details.supply, amount));
        sale.mint(recipient, tokenIds, amounts, "", saleIndexes, address(0), 0, proofs);
    }

    function test_mint_fail_supplyExceededOnSubsequentMint(
        bool useFactory,
        address recipient,
        IERC1155Sale.SaleDetails memory details,
        uint256 tokenId,
        uint256 minted,
        uint256 amount
    ) public withFactory(useFactory) {
        details = validSaleDetails(tokenId, details);
        details.supply = bound(details.supply, 1, type(uint256).max - 1);
        minted = bound(minted, 1, details.supply);
        uint256 saleIndex = test_mint_success(useFactory, recipient, details, tokenId, minted);

        // New amount exceeds supply
        amount = bound(amount, details.supply - minted + 1, type(uint256).max);

        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256[] memory saleIndexes = TestHelper.singleToArray(saleIndex);
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = TestHelper.blankProof();
        vm.expectRevert(
            abi.encodeWithSelector(IERC1155Sale.InsufficientSupply.selector, details.supply - minted, amount)
        );
        sale.mint(recipient, tokenIds, amounts, "", saleIndexes, address(0), 0, proofs);
    }

    function test_mint_fail_incorrectPayment(
        bool useFactory,
        address recipient,
        IERC1155Sale.SaleDetails memory details,
        uint256 tokenId,
        uint256 amount,
        uint256 expectedCost
    ) public withFactory(useFactory) {
        assumeSafeAddress(recipient);
        details = validSaleDetails(tokenId, details);
        if (details.cost == 0) {
            details.cost = 1;
        }
        uint256 saleIndex = sale.addSaleDetails(details);
        amount = bound(amount, 1, details.supply);
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256[] memory saleIndexes = TestHelper.singleToArray(saleIndex);
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = TestHelper.blankProof();

        uint256 realExpectedCost = details.cost * amount;
        expectedCost = bound(expectedCost, 0, realExpectedCost - 1); // Force different cost
        vm.deal(address(this), expectedCost);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Sale.InsufficientPayment.selector, details.paymentToken, realExpectedCost, expectedCost
            )
        );
        sale.mint{ value: expectedCost }(
            recipient, tokenIds, amounts, "", saleIndexes, address(0), expectedCost, proofs
        );
    }

    function test_mint_fail_insufficientPaymentERC20(
        bool useFactory,
        address recipient,
        IERC1155Sale.SaleDetails memory details,
        uint256 tokenId,
        uint256 amount,
        uint256 expectedCost
    ) public withFactory(useFactory) {
        assumeSafeAddress(recipient);
        details = validSaleDetails(tokenId, details);
        details.paymentToken = address(erc20);
        if (details.cost == 0) {
            details.cost = 1;
        }
        uint256 saleIndex = sale.addSaleDetails(details);
        amount = bound(amount, 1, details.supply);
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256[] memory saleIndexes = TestHelper.singleToArray(saleIndex);
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = TestHelper.blankProof();

        uint256 realExpectedCost = details.cost * amount;
        erc20.mint(address(this), realExpectedCost);
        erc20.approve(address(sale), expectedCost);
        expectedCost = bound(expectedCost, 0, realExpectedCost - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Sale.InsufficientPayment.selector, details.paymentToken, realExpectedCost, expectedCost
            )
        );
        sale.mint(recipient, tokenIds, amounts, "", saleIndexes, address(erc20), expectedCost, proofs);
    }

    function test_mint_fail_invalidExpectedPaymentToken(
        bool useFactory,
        address recipient,
        IERC1155Sale.SaleDetails memory details,
        uint256 tokenId,
        uint256 amount,
        address expectedPaymentToken
    ) public withFactory(useFactory) {
        assumeSafeAddress(recipient);
        details = validSaleDetails(tokenId, details);
        vm.assume(details.paymentToken != expectedPaymentToken);
        uint256 saleIndex = sale.addSaleDetails(details);
        amount = bound(amount, 1, details.supply);
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256[] memory saleIndexes = TestHelper.singleToArray(saleIndex);
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = TestHelper.blankProof();

        uint256 expectedCost = details.cost * amount;
        vm.deal(address(this), expectedCost);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Sale.PaymentTokenMismatch.selector, details.paymentToken, expectedPaymentToken
            )
        );
        sale.mint{ value: expectedCost }(
            recipient, tokenIds, amounts, "", saleIndexes, expectedPaymentToken, expectedCost, proofs
        );
    }

    function test_mint_fail_invalidExpectedCost(
        bool useFactory,
        address recipient,
        IERC1155Sale.SaleDetails memory details,
        uint256 tokenId,
        uint256 amount,
        uint256 expectedCost
    ) public withFactory(useFactory) {
        assumeSafeAddress(recipient);
        details = validSaleDetails(tokenId, details);
        if (details.cost == 0) {
            details.cost = 1;
        }
        uint256 saleIndex = sale.addSaleDetails(details);
        amount = bound(amount, 1, details.supply);
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256[] memory saleIndexes = TestHelper.singleToArray(saleIndex);
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = TestHelper.blankProof();

        uint256 realExpectedCost = details.cost * amount;
        vm.deal(address(this), realExpectedCost);
        expectedCost = bound(expectedCost, 0, realExpectedCost - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Sale.InsufficientPayment.selector, details.paymentToken, realExpectedCost, expectedCost
            )
        );
        sale.mint{ value: realExpectedCost }(
            recipient, tokenIds, amounts, "", saleIndexes, details.paymentToken, expectedCost, proofs
        );
    }

    function test_mint_fail_invalidExpectedCostERC20(
        bool useFactory,
        address recipient,
        IERC1155Sale.SaleDetails memory details,
        uint256 tokenId,
        uint256 amount,
        uint256 expectedCost
    ) public withFactory(useFactory) {
        assumeSafeAddress(recipient);
        details = validSaleDetails(tokenId, details);
        details.paymentToken = address(erc20);
        if (details.cost == 0) {
            details.cost = 1;
        }
        uint256 saleIndex = sale.addSaleDetails(details);
        amount = bound(amount, 1, details.supply);
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256[] memory saleIndexes = TestHelper.singleToArray(saleIndex);
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = TestHelper.blankProof();

        uint256 realExpectedCost = details.cost * amount;
        erc20.mint(address(this), realExpectedCost);
        erc20.approve(address(sale), expectedCost);
        expectedCost = bound(expectedCost, 0, realExpectedCost - 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IERC1155Sale.InsufficientPayment.selector, details.paymentToken, realExpectedCost, expectedCost
            )
        );
        sale.mint(recipient, tokenIds, amounts, "", saleIndexes, details.paymentToken, expectedCost, proofs);
    }

    function test_mint_fail_valueOnERC20Payment(
        bool useFactory,
        address recipient,
        IERC1155Sale.SaleDetails memory details,
        uint256 tokenId,
        uint256 amount,
        uint256 value
    ) public withFactory(useFactory) returns (uint256 saleIndex) {
        assumeSafeAddress(recipient);
        details = validSaleDetails(tokenId, details);
        details.paymentToken = address(erc20);
        saleIndex = sale.addSaleDetails(details);
        amount = bound(amount, 1, details.supply);
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256[] memory saleIndexes = TestHelper.singleToArray(saleIndex);
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = TestHelper.blankProof();

        uint256 expectedCost = details.cost * amount;
        erc20.mint(address(this), expectedCost);
        erc20.approve(address(sale), expectedCost);

        value = bound(value, 1, type(uint256).max);
        vm.deal(address(this), value);

        vm.expectRevert(abi.encodeWithSelector(IERC1155Sale.InsufficientPayment.selector, address(0), 0, value));
        sale.mint{ value: value }(recipient, tokenIds, amounts, "", saleIndexes, address(erc20), expectedCost, proofs);
    }

    function test_mint_multiple_success(
        bool useFactory,
        address recipient,
        IERC1155Sale.SaleDetails memory details1,
        IERC1155Sale.SaleDetails memory details2,
        uint256 tokenId1,
        uint256 tokenId2,
        uint256 amount1,
        uint256 amount2
    ) public withFactory(useFactory) {
        assumeSafeAddress(recipient);
        details1 = validSaleDetails(tokenId1, details1);
        details2 = validSaleDetails(tokenId2, details2);

        // Avoid overflows on total cost
        details1.cost = details1.cost / 2 + 1;
        details2.cost = details2.cost / 2 + 1;
        details1.supply = details1.supply / 2 + 1;
        details2.supply = details2.supply / 2 + 1;

        amount1 = bound(amount1, 1, details1.supply);
        amount2 = bound(amount2, 1, details2.supply);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId1;
        tokenIds[1] = tokenId2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;
        bytes32[][] memory proofs = new bytes32[][](2);
        uint256[] memory saleIndexes = new uint256[](2);

        saleIndexes[0] = sale.addSaleDetails(details1);
        saleIndexes[1] = sale.addSaleDetails(details2);

        uint256 totalCost = (details1.cost * amount1) + (details2.cost * amount2);
        vm.deal(address(this), totalCost);

        vm.expectEmit(true, true, true, true, address(token));
        emit TransferBatch(address(sale), address(0), recipient, tokenIds, amounts);
        vm.expectEmit(true, true, true, true, address(sale));
        emit IERC1155Sale.ItemsMinted(recipient, tokenIds, amounts, saleIndexes);
        sale.mint{ value: totalCost }(
            recipient, tokenIds, amounts, "", saleIndexes, details1.paymentToken, totalCost, proofs
        );

        assertEq(address(sale).balance, totalCost);
    }

    function test_mint_multiple_success_proof(
        bool useFactory,
        address recipient,
        IERC1155Sale.SaleDetails memory details1,
        IERC1155Sale.SaleDetails memory details2,
        uint256 tokenId1,
        uint256 tokenId2,
        uint256 amount1,
        uint256 amount2,
        address[] memory allowlist1,
        uint256 leafIndex1,
        address[] memory allowlist2,
        uint256 leafIndex2
    ) public withFactory(useFactory) {
        assumeSafeAddress(recipient);
        details1 = validSaleDetails(tokenId1, details1);
        details2 = validSaleDetails(tokenId2, details2);

        // Avoid overflows on total cost
        details1.cost = details1.cost / 2 + 1;
        details2.cost = details2.cost / 2 + 1;
        details1.supply = details1.supply / 2 + 1;
        details2.supply = details2.supply / 2 + 1;

        vm.assume(allowlist1.length > 1);
        leafIndex1 = bound(leafIndex1, 0, allowlist1.length - 1);

        vm.assume(allowlist2.length > 1);
        leafIndex2 = bound(leafIndex2, 0, allowlist2.length - 1);

        address sender = allowlist1[leafIndex1];
        allowlist2[leafIndex2] = sender;

        bytes32[][] memory proofs = new bytes32[][](2);
        (details1.merkleRoot, proofs[0]) = TestHelper.getMerkleParts(allowlist1, tokenId1, leafIndex1);
        (details2.merkleRoot, proofs[1]) = TestHelper.getMerkleParts(allowlist2, tokenId2, leafIndex2);

        amount1 = bound(amount1, 1, details1.supply);
        amount2 = bound(amount2, 1, details2.supply);
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId1;
        tokenIds[1] = tokenId2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;
        uint256[] memory saleIndexes = new uint256[](2);
        saleIndexes[0] = sale.addSaleDetails(details1);
        saleIndexes[1] = sale.addSaleDetails(details2);

        uint256 expectedCost = details1.cost * amount1 + details2.cost * amount2;
        vm.deal(sender, expectedCost);

        vm.expectEmit(true, true, true, true, address(token));
        emit TransferBatch(address(sale), address(0), recipient, tokenIds, amounts);
        vm.expectEmit(true, true, true, true, address(sale));
        emit IERC1155Sale.ItemsMinted(recipient, tokenIds, amounts, saleIndexes);
        vm.prank(sender);
        sale.mint{ value: expectedCost }(
            recipient, tokenIds, amounts, "", saleIndexes, address(0), expectedCost, proofs
        );

        assertEq(address(sale).balance, expectedCost);
    }

    function test_mint_multiple_success_ERC20(
        bool useFactory,
        address recipient,
        IERC1155Sale.SaleDetails memory details1,
        IERC1155Sale.SaleDetails memory details2,
        uint256 tokenId1,
        uint256 tokenId2,
        uint256 amount1,
        uint256 amount2
    ) public withFactory(useFactory) {
        assumeSafeAddress(recipient);
        details1 = validSaleDetails(tokenId1, details1);
        details2 = validSaleDetails(tokenId2, details2);

        details1.paymentToken = address(erc20);
        details2.paymentToken = address(erc20);

        // Avoid overflows on total cost
        details1.cost = details1.cost / 2 + 1;
        details2.cost = details2.cost / 2 + 1;
        details1.supply = details1.supply / 2 + 1;
        details2.supply = details2.supply / 2 + 1;

        amount1 = bound(amount1, 1, details1.supply);
        amount2 = bound(amount2, 1, details2.supply);

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId1;
        tokenIds[1] = tokenId2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;
        bytes32[][] memory proofs = new bytes32[][](2);
        uint256[] memory saleIndexes = new uint256[](2);

        saleIndexes[0] = sale.addSaleDetails(details1);
        saleIndexes[1] = sale.addSaleDetails(details2);

        uint256 totalCost = (details1.cost * amount1) + (details2.cost * amount2);
        erc20.mint(address(this), totalCost);
        erc20.approve(address(sale), totalCost);

        vm.expectEmit(true, true, true, true, address(token));
        emit TransferBatch(address(sale), address(0), recipient, tokenIds, amounts);
        vm.expectEmit(true, true, true, true, address(sale));
        emit IERC1155Sale.ItemsMinted(recipient, tokenIds, amounts, saleIndexes);
        sale.mint(recipient, tokenIds, amounts, "", saleIndexes, details1.paymentToken, totalCost, proofs);

        assertEq(erc20.balanceOf(address(this)), 0);
        assertEq(erc20.balanceOf(address(sale)), totalCost);
    }

    //
    // Helpers
    //
    modifier withFactory(
        bool useFactory
    ) {
        if (useFactory) {
            setUpFromFactory();
        }
        _;
    }

    function validSaleDetails(
        uint256 validTokenId,
        IERC1155Sale.SaleDetails memory saleDetails
    ) public view returns (IERC1155Sale.SaleDetails memory) {
        saleDetails.minTokenId = bound(saleDetails.minTokenId, 0, validTokenId);
        saleDetails.maxTokenId = bound(saleDetails.maxTokenId, validTokenId, type(uint256).max);
        saleDetails.supply = bound(saleDetails.supply, 1, type(uint256).max);
        saleDetails.cost = bound(saleDetails.cost, 0, type(uint256).max / saleDetails.supply);
        saleDetails.startTime = uint64(bound(saleDetails.startTime, 0, block.timestamp));
        saleDetails.endTime = uint64(bound(saleDetails.endTime, block.timestamp, type(uint64).max));
        saleDetails.paymentToken = address(0);
        saleDetails.merkleRoot = bytes32(0);
        return saleDetails;
    }

}
