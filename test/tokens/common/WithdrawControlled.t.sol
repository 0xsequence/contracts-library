// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { TestHelper } from "../../TestHelper.sol";

import { IWithdrawControlled, WithdrawControlled } from "src/tokens/common/WithdrawControlled.sol";

import { ERC20Mock } from "../../_mocks/ERC20Mock.sol";
import { IERC165 } from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import { WithdrawOnlyTo, WithdrawOnlyToFactory } from "src/payments/WithdrawOnlyToFactory.sol";

contract WithdrawControlledTest is TestHelper {

    bytes32 internal constant WITHDRAW_ROLE = keccak256("WITHDRAW_ROLE");

    WithdrawControlledFixture private _withdrawControlled;
    WithdrawOnlyToFactory private _withdrawOnlyToFactory;
    address private _owner;
    ERC20Mock private _token;

    function setUp() public {
        _owner = makeAddr("owner");
        _withdrawControlled = new WithdrawControlledFixture(_owner);
        _withdrawOnlyToFactory = new WithdrawOnlyToFactory();
        _token = new ERC20Mock(_owner);
    }

    function testSupportsInterface() public view {
        assertTrue(_withdrawControlled.supportsInterface(type(IERC165).interfaceId));
        assertTrue(_withdrawControlled.supportsInterface(type(IWithdrawControlled).interfaceId));
    }

    function testWithdrawERC20(uint256 amount, address withdrawTo) public {
        vm.assume(withdrawTo != address(_withdrawControlled));
        assumeSafeAddress(withdrawTo);
        _token.mint(address(_withdrawControlled), amount);

        vm.prank(_owner);
        _withdrawControlled.withdrawERC20(address(_token), withdrawTo, amount);

        assertEq(_token.balanceOf(withdrawTo), amount);
        assertEq(_token.balanceOf(address(_withdrawControlled)), 0);
    }

    function testWithdrawETH(uint256 amount, address withdrawTo) public {
        assumePayable(withdrawTo);
        vm.assume(withdrawTo.balance == 0);
        vm.assume(withdrawTo != address(_withdrawControlled));
        vm.deal(address(_withdrawControlled), amount);

        vm.prank(_owner);
        _withdrawControlled.withdrawETH(withdrawTo, amount);

        assertEq(address(_withdrawControlled).balance, 0);
        assertEq(withdrawTo.balance, amount);
    }

    function testWithdrawERC20WithOnlyTo(uint256 amount, address withdrawTo) public {
        vm.assume(withdrawTo != address(_withdrawControlled));
        assumeSafeAddress(withdrawTo);
        _token.mint(address(_withdrawControlled), amount);

        address onlyTo = _withdrawOnlyToFactory.deploy(withdrawTo);
        vm.prank(_owner);
        _withdrawControlled.grantRole(WITHDRAW_ROLE, onlyTo);

        WithdrawOnlyTo(onlyTo).withdrawERC20(address(_withdrawControlled), address(_token), amount);

        assertEq(_token.balanceOf(withdrawTo), amount);
        assertEq(_token.balanceOf(address(_withdrawControlled)), 0);
    }

    function testWithdrawETHWithOnlyTo(uint256 amount, address withdrawTo) public {
        vm.assume(withdrawTo != address(_withdrawControlled));
        vm.assume(withdrawTo.balance == 0);
        assumeSafeAddress(withdrawTo);
        vm.deal(address(_withdrawControlled), amount);

        address onlyTo = _withdrawOnlyToFactory.deploy(withdrawTo);
        vm.prank(_owner);
        _withdrawControlled.grantRole(WITHDRAW_ROLE, onlyTo);

        WithdrawOnlyTo(onlyTo).withdrawETH(address(_withdrawControlled), amount);

        assertEq(address(_withdrawControlled).balance, 0);
        assertEq(withdrawTo.balance, amount);
    }

}

contract WithdrawControlledFixture is WithdrawControlled {

    constructor(
        address owner
    ) {
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(WITHDRAW_ROLE, owner);
    }

}
