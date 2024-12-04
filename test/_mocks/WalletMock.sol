// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC721Receiver} from "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

contract WalletMock is IERC721Receiver {
    error CallFailed();

    function call(address to, uint256 value, bytes memory data) external {
        (bool success,) = to.call{value: value}(data);
        if (!success) revert CallFailed();
    }

    function onERC721Received(address, address, uint256, bytes memory) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
