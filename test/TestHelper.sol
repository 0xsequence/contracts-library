// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";

import {ITransparentUpgradeableBeaconProxy} from "src/proxies/TransparentUpgradeableBeaconProxy.sol";
import {ITransparentUpgradeableProxy} from "src/proxies/openzeppelin/TransparentUpgradeableProxy.sol";

abstract contract TestHelper is Test {
    function singleToArray(uint256 value) internal pure returns (uint256[] memory) {
        uint256[] memory values = new uint256[](1);
        values[0] = value;
        return values;
    }

    function blankProof() internal pure returns (bytes32[] memory) {
        return new bytes32[](0);
    }

    /**
     * Check for selector collisions against the proxy admin functions.
     */
    function checkSelectorCollision(bytes4 selector) internal {
        assertNotEq(selector, ITransparentUpgradeableProxy.upgradeTo.selector);
        assertNotEq(selector, ITransparentUpgradeableProxy.upgradeToAndCall.selector);
        assertNotEq(selector, ITransparentUpgradeableProxy.changeAdmin.selector);
        assertNotEq(selector, ITransparentUpgradeableProxy.admin.selector);
        assertNotEq(selector, ITransparentUpgradeableProxy.implementation.selector);
        assertNotEq(selector, ITransparentUpgradeableBeaconProxy.initialize.selector);
    }
}
