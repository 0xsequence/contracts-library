// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {SequenceProxyFactory} from "src/proxies/SequenceProxyFactory.sol";
import {ITransparentUpgradeableProxy} from "src/proxies/openzeppelin/TransparentUpgradeableProxy.sol";

contract MockImplementationV1 {
    function getValue() public pure virtual returns (uint256) {
        return 1;
    }
}

contract MockImplementationV2 is MockImplementationV1 {
    function getValue() public pure virtual override returns (uint256) {
        return 2;
    }
}

contract MockImplementationV3 is MockImplementationV1 {
    function getValue() public pure virtual override returns (uint256) {
        return 3;
    }
}

contract PublicSequenceProxyFactory is SequenceProxyFactory {
    constructor(address implementation, address factoryOwner) {
        _initialize(implementation, factoryOwner);
    }

    function createProxy(bytes32 salt, address proxyOwner, bytes memory data) external returns (address proxyAddress) {
        return _createProxy(salt, proxyOwner, data);
    }

    function computeProxyAddress(bytes32 salt, address proxyOwner, bytes memory data) external view returns (address) {
        return _computeProxyAddress(salt, proxyOwner, data);
    }
}

contract SequenceProxyFactoryTest is Test {
    PublicSequenceProxyFactory private factory;
    address private proxyOwner;
    address private impl1;
    address private impl2;
    address private impl3;

    function setUp() public {
        proxyOwner = makeAddr("proxyOwner");
        impl1 = address(new MockImplementationV1());
        impl2 = address(new MockImplementationV2());
        impl3 = address(new MockImplementationV3());
        factory = new PublicSequenceProxyFactory(impl1, address(this));
    }

    function testDeployProxy() public {
        address proxy = factory.createProxy(bytes32(""), proxyOwner, bytes(""));

        assertTrue(proxy != address(0));
        uint256 value = MockImplementationV1(proxy).getValue();
        assertEq(value, 1);
    }

    function testDeployProxyAfterUpgrade() public {
        factory.upgradeBeacon(impl2);

        address proxy = factory.createProxy(bytes32(""), proxyOwner, bytes(""));

        assertTrue(proxy != address(0));
        uint256 value = MockImplementationV1(proxy).getValue();
        assertEq(value, 2);
    }

    function testUpgradeAfterDeploy() public {
        address proxy = factory.createProxy(bytes32(""), proxyOwner, bytes(""));
        assertTrue(proxy != address(0));

        factory.upgradeBeacon(impl2);
        uint256 value = MockImplementationV1(proxy).getValue();
        assertEq(value, 2);
    }

    function testProxyOwnerUpgrade() public {
        address proxy = factory.createProxy(bytes32(""), proxyOwner, bytes(""));
        assertTrue(proxy != address(0));

        vm.prank(proxyOwner);
        ITransparentUpgradeableProxy(payable(proxy)).upgradeTo(impl2);

        uint256 value = MockImplementationV1(proxy).getValue();
        assertEq(value, 2);
    }

    function testProxyOwnerUpgradeUnaffectedByBeaconUpgrades() public {
        address proxy = factory.createProxy(bytes32(""), proxyOwner, bytes(""));
        assertTrue(proxy != address(0));

        vm.prank(proxyOwner);
        ITransparentUpgradeableProxy(payable(proxy)).upgradeTo(impl3);

        // Upgrade beacon
        factory.upgradeBeacon(impl2);

        uint256 value = MockImplementationV1(proxy).getValue();
        assertEq(value, 3);
    }

    function testAddressCompute() public {
        address expected = factory.createProxy(bytes32(""), proxyOwner, bytes(""));
        address actual = factory.computeProxyAddress(bytes32(""), proxyOwner, bytes(""));
        assertEq(actual, expected);
    }

    function testDuplicateDeploysFail() public {
        address proxy = factory.createProxy(bytes32(""), proxyOwner, bytes(""));
        assertTrue(proxy != address(0));

        vm.expectRevert("Create2: Failed on deploy");
        factory.createProxy(bytes32(""), proxyOwner, bytes(""));
    }
}
