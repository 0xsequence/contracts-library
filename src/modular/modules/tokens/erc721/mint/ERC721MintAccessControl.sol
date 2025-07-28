// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IExtension } from "../../../../interfaces/IExtension.sol";
import { AccessControlInternal } from "../../../accessControl/AccessControlInternal.sol";
import { ERC721Storage } from "../ERC721Storage.sol";
import { IERC721MintAccessControl } from "./IERC721MintAccessControl.sol";

/// @title ERC721MintAccessControl
/// @author Michael Standen
/// @notice Extension to enable minting of ERC721 tokens with access control.
/// @dev Relies on the access control module to check if the caller has the role.
contract ERC721MintAccessControl is AccessControlInternal, IExtension, IERC721MintAccessControl {

    bytes32 internal constant _MINT_ROLE = keccak256("MINT_ROLE");

    /// @dev `keccak256(bytes("Transfer(address,address,uint256)"))`.
    uint256 private constant _TRANSFER_EVENT_SIGNATURE =
        0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef;

    /// @dev See solady ERC721._mint
    function _mint(address to, uint256 id) internal {
        uint256 masterSlot = ERC721Storage._ERC721_MASTER_SLOT_SEED;
        uint256 maxAccountBalance = ERC721Storage._MAX_ACCOUNT_BALANCE;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Clear the upper 96 bits.
            to := shr(96, shl(96, to))
            // Use scratch space
            let m := mload(0x40)
            // Load the ownership data.
            mstore(m, id)
            mstore(add(m, 0x1c), masterSlot)
            let ownershipSlot := add(id, add(id, keccak256(m, 0x20)))
            let ownershipPacked := sload(ownershipSlot)
            // Revert if the token already exists.
            if shl(96, ownershipPacked) {
                mstore(0x00, 0xc991cbb1) // `TokenAlreadyExists()`.
                revert(0x1c, 0x04)
            }
            // Update with the owner.
            sstore(ownershipSlot, or(ownershipPacked, to))
            // Increment the balance of the owner.
            {
                mstore(m, to)
                mstore(add(m, 0x1c), masterSlot)
                let balanceSlot := keccak256(add(m, 0x0c), 0x1c)
                let balanceSlotPacked := add(sload(balanceSlot), 1)
                // Revert if `to` is the zero address, or if the account balance overflows.
                if iszero(mul(to, and(balanceSlotPacked, maxAccountBalance))) {
                    // `TransferToZeroAddress()`, `AccountBalanceOverflow()`.
                    mstore(shl(2, iszero(to)), 0xea553b3401336cea)
                    revert(0x1c, 0x04)
                }
                sstore(balanceSlot, balanceSlotPacked)
            }
            // Emit the {Transfer} event.
            log4(codesize(), 0x00, _TRANSFER_EVENT_SIGNATURE, 0, to, id)
        }
    }

    /// @inheritdoc IERC721MintAccessControl
    function mint(address to, uint256 tokenId) external onlyRole(_MINT_ROLE) {
        _mint(to, tokenId);
    }

    /// @inheritdoc IExtension
    function onAddExtension(
        bytes calldata initData
    ) external pure override {
        // no-op
    }

    /// @inheritdoc IExtension
    function extensionSupport() external pure override returns (ExtensionSupport memory support) {
        support.interfaces = new bytes4[](1);
        support.interfaces[0] = type(IERC721MintAccessControl).interfaceId;
        support.selectors = new bytes4[](1);
        support.selectors[0] = IERC721MintAccessControl.mint.selector;
        return support;
    }

}
