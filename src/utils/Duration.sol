// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {LibString} from "solady/utils/LibString.sol";

library Duration {
    using LibString for *;

    function format(uint256 totalSeconds) internal pure returns (string memory) {
        uint256 d = totalSeconds / (24 * 60 * 60);
        uint256 h = (totalSeconds % (24 * 60 * 60)) / (60 * 60);
        uint256 m = (totalSeconds % (60 * 60)) / 60;
        uint256 s = totalSeconds % 60;

        string memory result;

        if (d > 0) {
            result = string(abi.encodePacked(d.toString(), " days"));
        }
        if (h > 0) {
            result = bytes(result).length > 0
                ? string(abi.encodePacked(result, ", ", h.toString(), " hours"))
                : string(abi.encodePacked(h.toString(), " hours"));
        }
        if (m > 0) {
            result = bytes(result).length > 0
                ? string(abi.encodePacked(result, ", ", m.toString(), " minutes"))
                : string(abi.encodePacked(m.toString(), " minutes"));
        }
        if (s > 0) {
            result = bytes(result).length > 0
                ? string(abi.encodePacked(result, ", ", s.toString(), " seconds"))
                : string(abi.encodePacked(s.toString(), " seconds"));
        }

        return result;
    }
}
