// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IERC1155Receiver, IERC165 } from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";

contract ERC1155Recipient is IERC1155Receiver {

    error ExpectedRevert();

    bool public willRevert;
    uint256 public gasUsage; // Roughly how much gas to use in the spin loop

    function setWillRevert(
        bool _willRevert
    ) public {
        willRevert = _willRevert;
    }

    function setGasUsage(
        uint256 _gasUsage
    ) public {
        gasUsage = _gasUsage;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        uint256 gasStart = gasleft();
        if (willRevert) {
            revert ExpectedRevert();
        }
        while (gasStart - gasleft() < gasUsage) {
            // Spin
            // solhint-disable-next-line no-unused-vars
            uint256 a = uint256(0) / uint256(0);
        }
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        uint256 gasStart = gasleft();
        if (willRevert) {
            revert ExpectedRevert();
        }
        while (gasStart - gasleft() < gasUsage) {
            // Spin
            // solhint-disable-next-line no-unused-vars
            uint256 a = uint256(0) / uint256(0);
        }
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

}
