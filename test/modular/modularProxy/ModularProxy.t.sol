// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

// solhint-disable func-name-mixedcase

import { DefaultImpl } from "../_mocks/DefaultImpl.sol";
import { Test } from "forge-std/Test.sol";
import { IModule } from "src/modular/interfaces/IModule.sol";
import { IModularBase, ModularProxy } from "src/modular/modules/modularProxy/ModularProxy.sol";
import { IModularProxyFactory, ModularProxyFactory } from "src/modular/modules/modularProxy/ModularProxyFactory.sol";
import { IOwnable, Ownable } from "src/modular/modules/ownable/Ownable.sol";

contract ModularProxyTest is Test {

    ModularProxyFactory public factory;
    address public defaultImpl;
    Ownable public ownableImpl;

    function setUp() public {
        factory = new ModularProxyFactory();
        defaultImpl = address(new DefaultImpl());
        ownableImpl = new Ownable();
    }

    function test_factory_determineAddress(uint256 nonce, address defaultImpl_, address owner) public {
        address expectedAddress = factory.determineAddress(nonce, defaultImpl_, owner);
        vm.expectEmit(true, true, true, true);
        emit IModularProxyFactory.Deployed(expectedAddress);
        ModularProxy proxy = factory.deploy(nonce, defaultImpl_, owner);
        assertEq(address(proxy), expectedAddress);
    }

    function test_factory_deploy_fail_repeats(uint256 nonce, address defaultImpl_, address owner) public {
        factory.deploy(nonce, defaultImpl_, owner);
        vm.expectRevert();
        factory.deploy(nonce, defaultImpl_, owner);
    }

    function test_proxy_attachModule(uint256 nonce, address owner, address newOwner) public {
        ModularProxy proxy = factory.deploy(nonce, defaultImpl, owner);
        vm.assume(owner != newOwner);

        vm.expectEmit(true, true, true, true);
        emit IModularBase.ModuleAdded(ownableImpl);
        vm.prank(owner);
        proxy.attachModule(ownableImpl, "");

        // Can access functions
        assertEq(Ownable(address(proxy)).owner(), owner);

        // Supports new interface ids
        IModule.ModuleSupport memory support = ownableImpl.describeCapabilities();
        for (uint256 i = 0; i < support.interfaces.length; i++) {
            assertTrue(proxy.supportsInterface(support.interfaces[i]));
        }

        // Can transfer ownership
        vm.expectEmit(true, true, true, true);
        emit IOwnable.OwnershipTransferred(owner, newOwner);
        vm.prank(owner);
        Ownable(address(proxy)).transferOwnership(newOwner);
        assertEq(Ownable(address(proxy)).owner(), newOwner);

        // Consistent storage used
        vm.prank(owner);
        vm.expectRevert(IOwnable.CallerIsNotOwner.selector);
        proxy.attachModule(ownableImpl, "");
    }

    function test_proxy_attachModule_fail_notOwner(uint256 nonce, address owner, address notOwner) public {
        vm.assume(notOwner != owner);

        ModularProxy proxy = factory.deploy(nonce, defaultImpl, owner);

        vm.prank(notOwner);
        vm.expectRevert(IOwnable.CallerIsNotOwner.selector);
        proxy.attachModule(ownableImpl, "");
    }

    function test_proxy_detachModule(uint256 nonce, address owner) public {
        ModularProxy proxy = factory.deploy(nonce, defaultImpl, owner);

        vm.prank(owner);
        proxy.attachModule(ownableImpl, "");

        vm.expectEmit(true, true, true, true);
        emit IModularBase.ModuleRemoved(ownableImpl);
        vm.prank(owner);
        proxy.detachModule(ownableImpl);

        // Selectors are no longer supported
        IModule.ModuleSupport memory support = ownableImpl.describeCapabilities();
        for (uint256 i = 0; i < support.selectors.length; i++) {
            assertFalse(proxy.supportsInterface(support.selectors[i]));
        }

        // Can no longer access functions
        vm.prank(owner);
        vm.expectRevert();
        Ownable(address(proxy)).transferOwnership(owner);
    }

}
