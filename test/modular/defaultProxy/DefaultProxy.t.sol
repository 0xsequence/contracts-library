// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { Test } from "forge-std/Test.sol";

import { IERC165 } from "lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

import { DefaultProxy, IBase } from "src/modular/modules/defaultProxy/DefaultProxy.sol";
import { DefaultProxyFactory, IDefaultProxyFactory } from "src/modular/modules/defaultProxy/DefaultProxyFactory.sol";

import { IOwnable, Ownable } from "src/modular/modules/ownable/Ownable.sol";

contract DefaultImpl is IERC165 {

    function supportsInterface(
        bytes4 interfaceId
    ) public pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }

}

contract DefaultProxyTest is Test {

    DefaultProxyFactory public factory;
    address public defaultImpl;
    Ownable public ownableImpl;

    function setUp() public {
        factory = new DefaultProxyFactory();
        defaultImpl = address(new DefaultImpl());
        ownableImpl = new Ownable();
    }

    function test_factory_determineAddress(uint256 nonce, address defaultImpl_, address owner) public {
        address expectedAddress = factory.determineAddress(nonce, defaultImpl_, owner);
        vm.expectEmit(true, true, true, true);
        emit IDefaultProxyFactory.Deployed(expectedAddress);
        DefaultProxy proxy = factory.deploy(nonce, defaultImpl_, owner);
        assertEq(address(proxy), expectedAddress);
    }

    function test_factory_deploy_fail_repeats(uint256 nonce, address defaultImpl_, address owner) public {
        factory.deploy(nonce, defaultImpl_, owner);
        vm.expectRevert();
        factory.deploy(nonce, defaultImpl_, owner);
    }

    function test_proxy_addExtension(uint256 nonce, address owner, address newOwner) public {
        DefaultProxy proxy = factory.deploy(nonce, defaultImpl, owner);
        vm.assume(owner != newOwner);

        vm.expectEmit(true, true, true, true);
        emit IBase.ExtensionAdded(ownableImpl);
        vm.prank(owner);
        proxy.addExtension(ownableImpl, "");

        // Can access functions
        assertEq(Ownable(address(proxy)).owner(), owner);

        // Supports new interface ids
        bytes4[] memory interfaceIds = ownableImpl.supportedInterfaces();
        for (uint256 i = 0; i < interfaceIds.length; i++) {
            assertTrue(proxy.supportsInterface(interfaceIds[i]));
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
        proxy.addExtension(ownableImpl, "");
    }

    function test_proxy_addExtension_fail_notOwner(uint256 nonce, address owner, address notOwner) public {
        vm.assume(notOwner != owner);

        DefaultProxy proxy = factory.deploy(nonce, defaultImpl, owner);

        vm.prank(notOwner);
        vm.expectRevert(IOwnable.CallerIsNotOwner.selector);
        proxy.addExtension(ownableImpl, "");
    }

    function test_proxy_removeExtension(uint256 nonce, address owner) public {
        DefaultProxy proxy = factory.deploy(nonce, defaultImpl, owner);

        vm.prank(owner);
        proxy.addExtension(ownableImpl, "");

        vm.expectEmit(true, true, true, true);
        emit IBase.ExtensionRemoved(ownableImpl);
        vm.prank(owner);
        proxy.removeExtension(ownableImpl);

        // Selectors are no longer supported
        bytes4[] memory selectors = ownableImpl.supportedSelectors();
        for (uint256 i = 0; i < selectors.length; i++) {
            assertFalse(proxy.supportsInterface(selectors[i]));
        }

        // Can no longer access functions
        vm.prank(owner);
        vm.expectRevert();
        Ownable(address(proxy)).transferOwnership(owner);
    }

}
