// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

library TestHelper {

    function singleToArray(uint256 value) internal pure returns (uint256[] memory) {
        uint256[] memory values = new uint256[](1);
        values[0] = value;
        return values;
    }

    function blankProof() internal pure returns (bytes32[] memory) {
        return new bytes32[](0);
    }
}
