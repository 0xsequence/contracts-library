// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ERC721Items} from "@0xsequence/contracts-library/tokens/ERC721/presets/items/ERC721Items.sol";
import {OperatorAllowlistEnforced} from
    "@0xsequence/contracts-library/tokens/common/immutable/OperatorAllowlistEnforced.sol";
import {ERC721A, IERC721A} from "erc721a/contracts/ERC721A.sol";

error InvalidInitialization();

/**
 * An implementation of ERC-721 that enforces an operator allowlist.
 * See {OperatorAllowlistEnforced} for more details.
 */
contract ERC721OperatorEnforced is ERC721Items, OperatorAllowlistEnforced {
    constructor() ERC721Items() {}

    /**
     * Initialize contract.
     * @param owner The owner of the contract
     * @param tokenName Name of the token
     * @param tokenSymbol Symbol of the token
     * @param tokenBaseURI Base URI of the token
     * @param tokenContractURI Contract URI of the token
     * @param royaltyReceiver Address of who should be sent the royalty payment
     * @param royaltyFeeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @param operatorAllowlist Address of the operator allowlist
     * @dev This should be called immediately after deployment.
     */
    function initialize(
        address owner,
        string memory tokenName,
        string memory tokenSymbol,
        string memory tokenBaseURI,
        string memory tokenContractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        address operatorAllowlist
    ) public virtual {
        _setOperatorAllowlistRegistry(operatorAllowlist);
        ERC721Items.initialize(
            owner, tokenName, tokenSymbol, tokenBaseURI, tokenContractURI, royaltyReceiver, royaltyFeeNumerator
        );
    }

    //
    // Operator Allowlist
    //

    /**
     * Set the operator allowlist registry.
     * @param operatorAllowlist Address of the operator allowlist
     */
    function setOperatorAllowlistRegistry(address operatorAllowlist) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _setOperatorAllowlistRegistry(operatorAllowlist);
    }

    /// @inheritdoc ERC721A
    function _approve(address to, uint256 tokenId, bool approvalCheck) internal override validateApproval(to) {
        super._approve(to, tokenId, approvalCheck);
    }

    /// @inheritdoc ERC721A
    function setApprovalForAll(address operator, bool approved)
        public
        override(ERC721A, IERC721A)
        validateApproval(operator)
    {
        super.setApprovalForAll(operator, approved);
    }

    /// @inheritdoc ERC721A
    function _beforeTokenTransfers(address from, address to, uint256 startTokenId, uint256 quantity)
        internal
        override
    {
        if (from != address(0)) {
            // Ignore validation on minting
            _validateTransfer(from, to);
        }
        super._beforeTokenTransfers(from, to, startTokenId, quantity);
    }
}
