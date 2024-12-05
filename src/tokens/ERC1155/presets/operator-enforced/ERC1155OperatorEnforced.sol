// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ERC1155Items} from "@0xsequence/contracts-library/tokens/ERC1155/presets/items/ERC1155Items.sol";
import {OperatorAllowlistEnforced} from
    "@0xsequence/contracts-library/tokens/common/immutable/OperatorAllowlistEnforced.sol";

/**
 * An implementation of ERC-1155 that prevents transfers.
 */
contract ERC1155OperatorEnforced is ERC1155Items, OperatorAllowlistEnforced {
    constructor() ERC1155Items() {}

    /**
     * Initialize the contract.
     * @param owner Owner address
     * @param tokenName Token name
     * @param tokenBaseURI Base URI for token metadata
     * @param tokenContractURI Contract URI for token metadata
     * @param royaltyReceiver Address of who should be sent the royalty payment
     * @param royaltyFeeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @param operatorAllowlist Address of the operator allowlist
     * @dev This should be called immediately after deployment.
     */
    function initialize(
        address owner,
        string memory tokenName,
        string memory tokenBaseURI,
        string memory tokenContractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        address operatorAllowlist
    ) public virtual {
        _setOperatorAllowlistRegistry(operatorAllowlist);
        ERC1155Items.initialize(owner, tokenName, tokenBaseURI, tokenContractURI, royaltyReceiver, royaltyFeeNumerator);
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

    function setApprovalForAll(address operator, bool approved) public override validateApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    function _safeTransferFrom(address from, address to, uint256 id, uint256 amount) internal virtual override {
        if (from != address(0)) {
            // Ignore validation on minting
            _validateTransfer(from, to);
        }
        super._safeTransferFrom(from, to, id, amount);
    }

    function _safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts)
        internal
        virtual
        override
    {
        if (from != address(0)) {
            // Ignore validation on minting
            _validateTransfer(from, to);
        }
        super._safeBatchTransferFrom(from, to, ids, amounts);
    }

    function _burn(address from, uint256 id, uint256 amount)
        internal
        virtual
        override
        validateTransfer(from, address(0))
    {
        super._burn(from, id, amount);
    }

    function _batchBurn(address from, uint256[] memory ids, uint256[] memory amounts)
        internal
        virtual
        override
        validateTransfer(from, address(0))
    {
        super._batchBurn(from, ids, amounts);
    }
}
