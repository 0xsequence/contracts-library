// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {TestHelper} from "../TestHelper.sol";
import {ERC20Mock} from "../_mocks/ERC20Mock.sol";

import {PaymentCombiner, PaymentSplitter, IERC20Upgradeable} from "src/payments/PaymentCombiner.sol";
import {IPaymentCombiner, IPaymentCombinerSignals, IPaymentCombinerFunctions} from "src/payments/IPaymentCombiner.sol";
import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";

// Note we are not testing the OZ PaymentSplitter contract implementation, only the PaymentCombiner contract

contract PaymentCombinerTest is TestHelper, IPaymentCombinerSignals {
    PaymentCombiner public combiner;
    ERC20Mock public erc20;

    function setUp() public {
        combiner = new PaymentCombiner();
        erc20 = new ERC20Mock(address(this));
    }

    function testSupportsInterface() public view {
        assertTrue(combiner.supportsInterface(type(IERC165).interfaceId));
        assertTrue(combiner.supportsInterface(type(IPaymentCombiner).interfaceId));
        assertTrue(combiner.supportsInterface(type(IPaymentCombinerFunctions).interfaceId));
    }

    function _validArrays(address[] memory payees, uint256[] memory shares)
        internal
        view
        returns (address[] memory, uint256[] memory)
    {
        uint256 payeeLength = payees.length;
        vm.assume(payeeLength > 0);
        uint256 sharesLength = shares.length;
        vm.assume(sharesLength > 0);

        uint256 maxLen = 5;
        maxLen = payeeLength < maxLen ? payeeLength : maxLen;
        maxLen = sharesLength < maxLen ? sharesLength : maxLen;
        assembly {
            mstore(payees, maxLen)
            mstore(shares, maxLen)
        }

        // Make sure addr is safe
        for (uint256 i = 0; i < maxLen; i++) {
            assumeSafeAddress(payees[i]);
        }
        assumeNoDuplicates(payees);

        // Bind shares to prevent overflow
        for (uint256 i = 0; i < maxLen; i++) {
            shares[i] = _bound(shares[i], 1, 100);
        }

        return (payees, shares);
    }

    function testDetermineAddress(address[] memory payees, uint256[] memory shares) public {
        (payees, shares) = _validArrays(payees, shares);

        address expectedAddr = combiner.determineAddress(payees, shares);
        address actualAddr = combiner.deploy(payees, shares);
        assertEq(expectedAddr, actualAddr);
    }

    function testListPayeeSplitters(
        address[] memory payees1,
        address[] memory payees2,
        uint256[] memory shares1,
        uint256[] memory shares2
    ) public returns (address targetPayee, address[] memory splitterAddrs) {
        vm.assume(payees1.length > 0);
        vm.assume(payees2.length > 0);
        targetPayee = payees1[0];
        payees2[0] = targetPayee;
        (payees1, shares1) = _validArrays(payees1, shares1);
        (payees2, shares2) = _validArrays(payees2, shares2);

        address splitter1 = combiner.deploy(payees1, shares1);
        address splitter2 = combiner.deploy(payees2, shares2);
        splitterAddrs = combiner.listPayeeSplitters(targetPayee);
        assertEq(splitterAddrs.length, 2);
        assertEq(splitterAddrs[0], splitter1);
        assertEq(splitterAddrs[1], splitter2);
    }

    function testListReleasableNative(
        uint256 amount,
        address[] memory payees1,
        address[] memory payees2,
        uint256[] memory shares1,
        uint256[] memory shares2
    ) public returns (address targetPayee, address[] memory splitterAddrs) {
        (targetPayee, splitterAddrs) = testListPayeeSplitters(payees1, payees2, shares1, shares2);

        amount = _bound(amount, 0.1 ether, 1 ether);
        vm.deal(address(this), amount * splitterAddrs.length);

        for (uint256 i = 0; i < splitterAddrs.length; i++) {
            // Fund splitters
            payable(splitterAddrs[i]).transfer(amount);
        }

        uint256[] memory pendingShares = combiner.listReleasable(payable(targetPayee), address(0), splitterAddrs);

        for (uint256 i = 0; i < splitterAddrs.length; i++) {
            PaymentSplitter splitter = PaymentSplitter(payable(splitterAddrs[i]));
            assertEq(splitter.releasable(targetPayee), pendingShares[i]);
        }
    }

    function testListReleasableERC20(
        uint256 amount,
        address[] memory payees1,
        address[] memory payees2,
        uint256[] memory shares1,
        uint256[] memory shares2
    ) public returns (address targetPayee, address[] memory splitterAddrs) {
        (targetPayee, splitterAddrs) = testListPayeeSplitters(payees1, payees2, shares1, shares2);

        amount = _bound(amount, 0.1 ether, 1 ether);
        erc20.mint(address(this), 0, amount * splitterAddrs.length);

        for (uint256 i = 0; i < splitterAddrs.length; i++) {
            // Fund splitters
            erc20.transfer(splitterAddrs[i], amount);
        }

        uint256[] memory pendingShares = combiner.listReleasable(payable(targetPayee), address(erc20), splitterAddrs);

        for (uint256 i = 0; i < splitterAddrs.length; i++) {
            PaymentSplitter splitter = PaymentSplitter(payable(splitterAddrs[i]));
            assertEq(splitter.releasable(IERC20Upgradeable(address(erc20)), targetPayee), pendingShares[i]);
        }
    }

    function testListReleaseNative(
        uint256 amount,
        address[] memory payees1,
        address[] memory payees2,
        uint256[] memory shares1,
        uint256[] memory shares2
    ) public {
        (address targetPayee, address[] memory splitterAddrs) =
            testListReleasableNative(amount, payees1, payees2, shares1, shares2);

        combiner.release(payable(targetPayee), address(0), splitterAddrs);

        for (uint256 i = 0; i < splitterAddrs.length; i++) {
            PaymentSplitter splitter = PaymentSplitter(payable(splitterAddrs[i]));
            assertGt(splitter.released(targetPayee), 0);
            assertEq(splitter.released(IERC20Upgradeable(address(erc20)), targetPayee), 0);
        }
    }

    function testListReleaseERC20(
        uint256 amount,
        address[] memory payees1,
        address[] memory payees2,
        uint256[] memory shares1,
        uint256[] memory shares2
    ) public {
        (address targetPayee, address[] memory splitterAddrs) =
            testListReleasableERC20(amount, payees1, payees2, shares1, shares2);

        combiner.release(payable(targetPayee), address(erc20), splitterAddrs);

        for (uint256 i = 0; i < splitterAddrs.length; i++) {
            PaymentSplitter splitter = PaymentSplitter(payable(splitterAddrs[i]));
            assertGt(splitter.released(IERC20Upgradeable(address(erc20)), targetPayee), 0);
            assertEq(splitter.released(targetPayee), 0);
        }
    }
}
