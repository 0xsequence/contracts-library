// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

contract WalletMock {
    function execute(address to, uint256 value, bytes memory data) external returns (bool, bytes memory) {
        (bool success, bytes memory result) = to.call{value: value}(data);
        return (success, result);
    }
}
