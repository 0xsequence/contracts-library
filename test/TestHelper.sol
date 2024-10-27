// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import {ITransparentUpgradeableBeaconProxy} from "src/proxies/TransparentUpgradeableBeaconProxy.sol";
import {ITransparentUpgradeableProxy} from "src/proxies/openzeppelin/TransparentUpgradeableProxy.sol";

import {Merkle} from "murky/Merkle.sol";

abstract contract TestHelper is Test, Merkle {
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
    function checkSelectorCollision(bytes4 selector) internal pure {
        assertNotEq(selector, ITransparentUpgradeableProxy.upgradeTo.selector);
        assertNotEq(selector, ITransparentUpgradeableProxy.upgradeToAndCall.selector);
        assertNotEq(selector, ITransparentUpgradeableProxy.changeAdmin.selector);
        assertNotEq(selector, ITransparentUpgradeableProxy.admin.selector);
        assertNotEq(selector, ITransparentUpgradeableProxy.implementation.selector);
        assertNotEq(selector, ITransparentUpgradeableBeaconProxy.initialize.selector);
    }

    function assumeSafeAddress(address addr) internal view {
        vm.assume(addr != address(0));
        assumeNotPrecompile(addr);
        assumeNotForgeAddress(addr);
        vm.assume(addr.code.length == 0); // Non contract
    }

    function assumeNoDuplicates(uint256[] memory values) internal pure {
        for (uint256 i = 0; i < values.length; i++) {
            for (uint256 j = i + 1; j < values.length; j++) {
                vm.assume(values[i] != values[j]);
            }
        }
    }


    function getMerkleParts(address[] memory allowlist, uint256 salt, uint256 leafIndex)
        internal
        pure
        returns (bytes32 root, bytes32[] memory proof)
    {

        bytes32[] memory leaves = new bytes32[](allowlist.length);
        for (uint256 i = 0; i < allowlist.length; i++) {
            leaves[i] = keccak256(abi.encodePacked(allowlist[i], salt));
        }
        root = getRoot(leaves);
        proof = getProof(leaves, leafIndex);
    }
}
