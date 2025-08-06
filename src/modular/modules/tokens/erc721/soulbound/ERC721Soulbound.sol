// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IModule } from "../../../../interfaces/IModule.sol";

import { LibBytes } from "../../../../utils/LibBytes.sol";
import { AccessControlInternal } from "../../../accessControl/AccessControl.sol";
import { ModularProxyStorage } from "../../../modularProxy/ModularProxyStorage.sol";
import { ERC721SoulboundStorage } from "./ERC721SoulboundStorage.sol";
import { IERC721Soulbound } from "./IERC721Soulbound.sol";
import { ERC721 as SoladyERC721 } from "lib/solady/src/tokens/ERC721.sol";

/// @title ERC721Soulbound
/// @author Michael Standen
/// @notice Disables transfers of ERC721 tokens
contract ERC721Soulbound is AccessControlInternal, IERC721Soulbound, IModule {

    error TransferFailed();

    bytes32 private constant _TRANSFER_ADMIN_ROLE = keccak256("TRANSFER_ADMIN_ROLE");

    /// @dev Transfers token `id` from `from` to `to`.
    ///
    /// Requirements:
    ///
    /// - Token `id` must exist.
    /// - `from` must be the owner of the token.
    /// - `to` cannot be the zero address.
    /// - The caller must be the owner of the token, or be approved to manage the token.
    ///
    /// Emits a {Transfer} event.
    function transferFrom(address, address, uint256) public payable {
        if (ERC721SoulboundStorage.load().transferLocked) {
            revert TransfersLocked();
        }
        // Forward the call to the default implementation (ERC721 hopefully)
        address defaultImpl = ModularProxyStorage.loadDefaultImpl();
        // solhint-disable-next-line avoid-low-level-calls
        (bool success,) = defaultImpl.delegatecall(msg.data);
        if (!success) {
            revert TransferFailed();
        }
    }

    /// @inheritdoc IERC721Soulbound
    function setTransferLocked(
        bool locked
    ) public virtual onlyRole(_TRANSFER_ADMIN_ROLE) {
        ERC721SoulboundStorage.load().transferLocked = locked;
    }

    /// @inheritdoc IERC721Soulbound
    function getTransferLocked() public view virtual returns (bool) {
        return ERC721SoulboundStorage.load().transferLocked;
    }

    /// @inheritdoc IModule
    /// @param initData Transfer admin and transfer lock
    function onAttachModule(
        bytes calldata initData
    ) public virtual override {
        bool locked = true;
        if (initData.length > 0) {
            uint256 pointer = 0;
            address transferAdmin;
            (transferAdmin, pointer) = LibBytes.readAddress(initData, pointer);
            AccessControlInternal._setHasRole(_TRANSFER_ADMIN_ROLE, transferAdmin, true);
            if (initData.length > pointer) {
                (locked,) = LibBytes.readBool(initData, pointer);
            }
        }
        ERC721SoulboundStorage.load().transferLocked = locked;
    }

    /// @inheritdoc IModule
    function describeCapabilities() public pure virtual override returns (ModuleSupport memory support) {
        support.interfaces = new bytes4[](1);
        support.interfaces[0] = type(IERC721Soulbound).interfaceId;
        support.selectors = new bytes4[](3);
        support.selectors[0] = SoladyERC721.transferFrom.selector; // Override the default implementation
        support.selectors[1] = IERC721Soulbound.setTransferLocked.selector;
        support.selectors[2] = IERC721Soulbound.getTransferLocked.selector;
        return support;
    }

}
