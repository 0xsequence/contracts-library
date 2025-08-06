// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

// solhint-disable func-name-mixedcase

import { DefaultImpl } from "../_mocks/DefaultImpl.sol";
import { Test } from "forge-std/Test.sol";
import { AccessControl, IAccessControl } from "src/modular/modules/accessControl/AccessControl.sol";
import { ModularProxy } from "src/modular/modules/modularProxy/ModularProxy.sol";
import { ModularProxyFactory } from "src/modular/modules/modularProxy/ModularProxyFactory.sol";

contract AccessControlTest is Test {

    ModularProxyFactory public factory;
    address public defaultImpl;
    AccessControl public accessControlImpl;

    function setUp() public {
        factory = new ModularProxyFactory();
        defaultImpl = address(new DefaultImpl());
        accessControlImpl = new AccessControl();
    }

    function test_accessControl_roles(
        uint256 nonce,
        address owner,
        address defaultAdmin,
        bytes32 role,
        address account
    ) public {
        vm.assume(defaultAdmin != owner);

        ModularProxy proxy = factory.deploy(nonce, defaultImpl, owner);
        bytes memory initData = abi.encodePacked(defaultAdmin);

        // On add extension

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IAccessControl.RoleGranted(0x00, defaultAdmin, address(owner));
        vm.prank(owner);
        proxy.attachModule(accessControlImpl, initData);

        AccessControl accessControl = AccessControl(address(proxy));

        assertFalse(accessControl.hasRole(0x00, owner));
        assertTrue(accessControl.hasRole(0x00, defaultAdmin));

        // Can add a role
        vm.expectEmit(true, true, true, true, address(proxy));
        emit IAccessControl.RoleGranted(role, account, defaultAdmin);
        vm.prank(defaultAdmin);
        accessControl.grantRole(role, account);

        // Can check if the account has the role
        assertTrue(accessControl.hasRole(role, account));

        // Can revoke a role
        vm.expectEmit(true, true, true, true, address(proxy));
        emit IAccessControl.RoleRevoked(role, account, defaultAdmin);
        vm.prank(defaultAdmin);
        accessControl.revokeRole(role, account);

        // Can check if the account has the role
        assertFalse(accessControl.hasRole(role, owner));
    }

    function test_accessControl_fail_notAdmin(uint256 nonce, address owner, bytes32 role, address account) public {
        ModularProxy proxy = factory.deploy(nonce, defaultImpl, owner);

        // Do not set an admin
        vm.prank(owner);
        proxy.attachModule(accessControlImpl, "");

        AccessControl accessControl = AccessControl(address(proxy));

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSelector(IAccessControl.NoRole.selector, owner, 0x00));
        accessControl.grantRole(role, account);
    }

}
