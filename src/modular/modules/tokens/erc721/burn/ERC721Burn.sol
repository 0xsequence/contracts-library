// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IExtension } from "../../../../interfaces/IExtension.sol";
import { ERC721Storage } from "../ERC721Storage.sol";
import { IERC721Burn } from "./IERC721Burn.sol";

/// @title ERC721Burn
/// @author Michael Standen
/// @notice Enables burning of ERC721 tokens.
contract ERC721Burn is IExtension, IERC721Burn {

    /// @dev `keccak256(bytes("Transfer(address,address,uint256)"))`.
    uint256 private constant _TRANSFER_EVENT_SIGNATURE =
        0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    /// @dev See solady ERC721._burn
    function _burn(address by, uint256 id) internal {
        uint256 masterSlot = ERC721Storage._ERC721_MASTER_SLOT_SEED;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            by := shr(96, shl(96, by))

            mstore(0x00, id)
            mstore(0x1c, masterSlot)
            let ownershipSlot := add(id, add(id, keccak256(0x00, 0x20)))
            let ownershipPacked := sload(ownershipSlot)
            let owner := shr(96, shl(96, ownershipPacked))

            if iszero(owner) {
                mstore(0x00, 0xceea21b6) // TokenDoesNotExist()
                revert(0x1c, 0x04)
            }

            let approvedSlot := add(1, ownershipSlot)
            let approved := sload(approvedSlot)

            if iszero(or(iszero(by), or(eq(by, owner), eq(by, approved)))) {
                mstore(0x00, owner)
                mstore(0x1c, or(masterSlot, by))
                if iszero(sload(keccak256(0x0c, 0x30))) {
                    mstore(0x00, 0x4b6e7f18) // NotOwnerNorApproved()
                    revert(0x1c, 0x04)
                }
            }

            if approved { sstore(approvedSlot, 0) }

            // Clear only owner (lower 160 bits), keep extraData
            let clearMask := not(sub(shl(160, 1), 1))
            sstore(ownershipSlot, and(ownershipPacked, clearMask))

            mstore(0x00, owner)
            mstore(0x1c, masterSlot)
            let balanceSlot := keccak256(0x0c, 0x1c)
            sstore(balanceSlot, sub(sload(balanceSlot), 1))

            log4(codesize(), 0x00, 0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef, owner, 0, id)
        }
    }

    /// @inheritdoc IERC721Burn
    function burn(
        uint256 tokenId
    ) public virtual {
        _burn(msg.sender, tokenId);
    }

    /// @inheritdoc IERC721Burn
    function batchBurn(
        uint256[] memory tokenIds
    ) public virtual {
        uint256 nBurn = tokenIds.length;
        for (uint256 i = 0; i < nBurn; i++) {
            _burn(msg.sender, tokenIds[i]);
        }
    }

    /// @inheritdoc IExtension
    function onAddExtension(
        bytes calldata initData
    ) external pure override {
        // no-op
    }

    /// @inheritdoc IExtension
    function supportedSelectors() external pure override returns (bytes4[] memory selectors) {
        selectors = new bytes4[](2);
        selectors[0] = IERC721Burn.burn.selector;
        selectors[1] = IERC721Burn.batchBurn.selector;
        return selectors;
    }

    /// @inheritdoc IExtension
    function supportedInterfaces() external pure override returns (bytes4[] memory interfaceIds) {
        interfaceIds = new bytes4[](1);
        interfaceIds[0] = type(IERC721Burn).interfaceId;
        return interfaceIds;
    }

}
