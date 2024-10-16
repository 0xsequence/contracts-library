// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ERC721Items} from "@0xsequence/contracts-library/tokens/ERC721/presets/items/ERC721Items.sol";
import {CreatorTokenBase, ICreatorToken} from "@limitbreak/creator-token-standards/utils/CreatorTokenBase.sol";
import {TOKEN_TYPE_ERC721} from "@limitbreak/permit-c/Constants.sol";

/**
 * An implementation of ERC-721 capable of minting when role provided.
 */
contract ERC721CItems is ERC721Items, CreatorTokenBase {
    bytes32 internal constant _TRANSFER_ADMIN_ROLE = keccak256("TRANSFER_ADMIN_ROLE");

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
        _grantRole(_TRANSFER_ADMIN_ROLE, owner);

        super.initialize(
            owner, tokenName, tokenSymbol, tokenBaseURI, tokenContractURI, royaltyReceiver, royaltyFeeNumerator
        );
    }

    function _tokenType() internal pure override returns (uint16) {
        return uint16(TOKEN_TYPE_ERC721);
    }

    function _requireCallerIsContractOwner() internal view override {
        _checkRole(_TRANSFER_ADMIN_ROLE);
    }

    function getTransferValidationFunction() external pure returns (bytes4 functionSignature, bool isViewFunction) {
        functionSignature = bytes4(keccak256("validateTransfer(address,address,address,uint256)"));
        isViewFunction = true;
    }

    /* FIXME
    /// @inheritdoc CreatorTokenBase
    function getTransferValidator() public view override returns (address validator) {
        validator = transferValidator;
        // Do not use the default validator
    }
    */

    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity) internal virtual override {
        for (uint256 i = 0; i < quantity;) {
            _validateBeforeTransfer(from, to, startTokenId + i);
            unchecked {
                ++i;
            }
        }
    }

    function _afterTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity) internal virtual override {
        for (uint256 i = 0; i < quantity;) {
            _validateAfterTransfer(from, to, startTokenId + i);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * Check interface support.
     * @param interfaceId Interface id
     * @return True if supported
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return type(ICreatorToken).interfaceId == interfaceId || super.supportsInterface(interfaceId);
    }
}
