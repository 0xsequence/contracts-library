// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IERC1155Pack } from "src/tokens/ERC1155/presets/pack/IERC1155Pack.sol";

import { ERC1155Receiver } from "openzeppelin-contracts/contracts/token/ERC1155/utils/ERC1155Receiver.sol";

contract PackReentryMock is ERC1155Receiver {

    address private _targetContract;
    bytes32[] private _proof;
    IERC1155Pack.PackContent private _pack;

    constructor(
        address targetContract
    ) {
        _targetContract = targetContract;
    }

    function setPackAndProof(bytes32[] calldata proof, IERC1155Pack.PackContent calldata pack) external {
        _proof = proof;
        _pack = pack;
    }

    function commit() external {
        IERC1155Pack(_targetContract).commit();
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata data
    ) external override returns (bytes4) {
        if (data.length == 0) {
            IERC1155Pack(_targetContract).reveal(address(this), _pack, _proof);
        }
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata data
    ) external override returns (bytes4) {
        if (data.length == 0) {
            IERC1155Pack(_targetContract).reveal(address(this), _pack, _proof);
        }
        return this.onERC1155BatchReceived.selector;
    }

}
