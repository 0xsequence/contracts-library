// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ERC721Items} from "@0xsequence/contracts-library/tokens/ERC721/presets/items/ERC721Items.sol";
import {
    IERC721Soulbound,
    IERC721SoulboundFunctions
} from "@0xsequence/contracts-library/tokens/ERC721/presets/soulbound/IERC721Soulbound.sol";

/**
 * An implementation of ERC-721 that prevents transfers.
 */
contract ERC721Soulbound is ERC721Items, IERC721Soulbound {
    bytes32 public constant TRANSFER_ADMIN_ROLE = keccak256("TRANSFER_ADMIN_ROLE");

    bool internal _transferLocked;

    constructor() ERC721Items() {}

    /// @inheritdoc ERC721Items
    function initialize(
        address owner,
        string memory tokenName,
        string memory tokenSymbol,
        string memory tokenBaseURI,
        string memory tokenContractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) public virtual override {
        _transferLocked = true;
        _grantRole(TRANSFER_ADMIN_ROLE, owner);
        super.initialize(
            owner, tokenName, tokenSymbol, tokenBaseURI, tokenContractURI, royaltyReceiver, royaltyFeeNumerator
        );
    }

    /// @inheritdoc IERC721SoulboundFunctions
    function setTransferLocked(bool locked) external override onlyRole(TRANSFER_ADMIN_ROLE) {
        _transferLocked = locked;
    }

    /// @inheritdoc IERC721SoulboundFunctions
    function getTransferLocked() external view override returns (bool) {
        return _transferLocked;
    }

    function _beforeTokenTransfers(address from, address to, uint256 startTokenId, uint256 quantity)
        internal
        virtual
        override
    {
        // Mint transactions allowed
        if (_transferLocked && from != address(0)) {
            revert TransfersLocked();
        }
        super._beforeTokenTransfers(from, to, startTokenId, quantity);
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return type(IERC721SoulboundFunctions).interfaceId == interfaceId || super.supportsInterface(interfaceId);
    }
}
