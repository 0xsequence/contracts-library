// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IOperatorAllowlist} from "src/tokens/common/immutable/IOperatorAllowlist.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

contract OperatorAllowlistMock is IOperatorAllowlist, IERC165 {
    mapping(address operator => bool isAllowed) private _allowlisted;

    function setAllowlisted(address operator, bool allowlisted) external {
        _allowlisted[operator] = allowlisted;
    }

    function isAllowlisted(address operator) external view returns (bool) {
        return _allowlisted[operator];
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == type(IOperatorAllowlist).interfaceId || interfaceId == type(IERC165).interfaceId;
    }
}
