// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IERC165 } from "lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

/// @title DefaultImpl
/// @author Michael Standen
/// @notice Default implementation for the ModularProxy
contract DefaultImpl is IERC165 {

    function supportsInterface(
        bytes4 interfaceId
    ) public pure returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }

}
