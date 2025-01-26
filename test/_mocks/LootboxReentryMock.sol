// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";
import {IERC1155Lootbox} from "src/tokens/ERC1155/presets/lootbox/IERC1155Lootbox.sol";

contract LootboxReentryMock is ERC1155Receiver {
    address private _targetContract;
    bytes32[] private _proof;
    IERC1155Lootbox.BoxContent private _box;

    constructor(address targetContract) {
        _targetContract = targetContract;
    }

    function setBoxAndProof(bytes32[] calldata proof, IERC1155Lootbox.BoxContent calldata box) external {
        _proof = proof;
        _box = box;
    }

    function commit() external {
        IERC1155Lootbox(_targetContract).commit();
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        if (data.length == 0) {
            IERC1155Lootbox(_targetContract).reveal(address(this), _box, _proof);
        }
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata data)
        external
        override
        returns (bytes4)
    {
        if (data.length == 0) {
            IERC1155Lootbox(_targetContract).reveal(address(this), _box, _proof);
        }
        return this.onERC1155BatchReceived.selector;
    }
}
