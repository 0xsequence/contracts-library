// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { ERC1155Items } from "../items/ERC1155Items.sol";
import { IERC1155Soulbound, IERC1155SoulboundFunctions } from "./IERC1155Soulbound.sol";

import { ERC1155 } from "solady/tokens/ERC1155.sol";

/**
 * An implementation of ERC-1155 that prevents transfers.
 */
contract ERC1155Soulbound is ERC1155Items, IERC1155Soulbound {

    bytes32 public constant TRANSFER_ADMIN_ROLE = keccak256("TRANSFER_ADMIN_ROLE");

    bool internal _transferLocked;

    /// @inheritdoc ERC1155Items
    function initialize(
        address owner,
        string memory tokenName,
        string memory tokenBaseURI,
        string memory tokenContractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        address implicitModeValidator,
        bytes32 implicitModeProjectId
    ) public virtual override {
        _transferLocked = true;
        _grantRole(TRANSFER_ADMIN_ROLE, owner);
        super.initialize(
            owner,
            tokenName,
            tokenBaseURI,
            tokenContractURI,
            royaltyReceiver,
            royaltyFeeNumerator,
            implicitModeValidator,
            implicitModeProjectId
        );
    }

    /// @inheritdoc IERC1155SoulboundFunctions
    function setTransferLocked(
        bool locked
    ) external override onlyRole(TRANSFER_ADMIN_ROLE) {
        _transferLocked = locked;
    }

    /// @inheritdoc IERC1155SoulboundFunctions
    function getTransferLocked() external view override returns (bool) {
        return _transferLocked;
    }

    // Transfer hooks

    /// @dev Use the beforeTokenTransfer hook to block transfers
    function _useBeforeTokenTransfer() internal pure override returns (bool) {
        return true;
    }

    /// @inheritdoc ERC1155
    /// @dev Block transfers if the token is soulbound
    /// @dev Mint transactions allowed
    function _beforeTokenTransfer(
        address from,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) internal virtual override {
        if (_transferLocked && from != address(0)) {
            revert TransfersLocked();
        }
    }

    function _burn(address from, uint256 id, uint256 amount) internal virtual override {
        if (_transferLocked) {
            revert TransfersLocked();
        }
        super._burn(from, id, amount);
    }

    function _batchBurn(address from, uint256[] memory ids, uint256[] memory amounts) internal virtual override {
        if (_transferLocked) {
            revert TransfersLocked();
        }
        super._batchBurn(from, ids, amounts);
    }

    // Views

    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return type(IERC1155SoulboundFunctions).interfaceId == interfaceId || super.supportsInterface(interfaceId);
    }

}
