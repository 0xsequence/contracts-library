// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { ERC721Storage } from "../../../../bases/erc721/ERC721Storage.sol";
import { IModule } from "../../../../interfaces/IModule.sol";
import { LibBytes } from "../../../../utils/LibBytes.sol";
import { AccessControlInternal } from "../../../accessControl/AccessControlInternal.sol";
import { ERC721MintAccessControlStorage } from "./ERC721MintAccessControlStorage.sol";
import { IERC721MintAccessControl } from "./IERC721MintAccessControl.sol";

/// @title ERC721MintAccessControl
/// @author Michael Standen
/// @notice Module to enable minting of ERC721 tokens with access control.
/// @dev Relies on the access control module to check if the caller has the role.
contract ERC721MintAccessControl is AccessControlInternal, IModule, IERC721MintAccessControl {

    bytes32 internal constant _MINTER_ROLE = keccak256("MINTER_ROLE");

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

    /// @dev See solady ERC721._exists
    function _exists(
        uint256 id
    ) internal view returns (bool result) {
        uint256 masterSlot = ERC721Storage._ERC721_MASTER_SLOT_SEED;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let m := mload(0x40)
            mstore(m, id)
            mstore(add(m, 0x1c), masterSlot)
            let ownershipSlot := add(id, add(id, keccak256(m, 0x20)))
            let ownershipPacked := sload(ownershipSlot)
            result := iszero(iszero(shl(96, ownershipPacked)))
        }
    }

    /// @inheritdoc IERC721MintAccessControl
    function mint(address to, uint256 tokenId) public virtual onlyRole(_MINTER_ROLE) {
        _mint(to, tokenId);
        ERC721Storage.loadSupply().totalSupply++;
    }

    /// @inheritdoc IERC721MintAccessControl
    function mintSequential(address to, uint256 amount) public virtual onlyRole(_MINTER_ROLE) {
        ERC721MintAccessControlStorage.Data storage data = ERC721MintAccessControlStorage.load();
        uint256 nextSequentialId = data.nextSequentialId;
        for (uint256 i = 0; i < amount; i++) {
            while (_exists(nextSequentialId)) {
                nextSequentialId++;
            }
            _mint(to, nextSequentialId);
            nextSequentialId++;
        }
        data.nextSequentialId = nextSequentialId;
        ERC721Storage.loadSupply().totalSupply += amount;
    }

    /// @inheritdoc IModule
    /// @dev If initData is provided, the minter role is granted to the address in initData.
    function onAttachModule(
        bytes calldata initData
    ) public virtual override {
        if (initData.length > 0) {
            address minter;
            (minter,) = LibBytes.readAddress(initData, 0);
            AccessControlInternal._setHasRole(_MINTER_ROLE, minter, true);
        }
    }

    /// @inheritdoc IModule
    function describeCapabilities() public pure virtual override returns (ModuleSupport memory support) {
        support.interfaces = new bytes4[](1);
        support.interfaces[0] = type(IERC721MintAccessControl).interfaceId;
        support.selectors = new bytes4[](2);
        support.selectors[0] = IERC721MintAccessControl.mint.selector;
        support.selectors[1] = IERC721MintAccessControl.mintSequential.selector;
        return support;
    }

}
