// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC1155Receiver} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";
import {IERC721Receiver} from "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

contract WalletMock is IERC1155Receiver, IERC721Receiver {
    error CallFailed();

    function call(address to, uint256 value, bytes memory data) external {
        (bool success,) = to.call{value: value}(data);
        if (!success) revert CallFailed();
    }

    function onERC721Received(address, address, uint256, bytes memory) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes memory) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory)
        external
        pure
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return interfaceId == this.onERC1155Received.selector || interfaceId == this.onERC1155BatchReceived.selector;
    }
}
