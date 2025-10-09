// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { ERC1155BaseToken, ERC2981Controlled } from "../../ERC1155BaseToken.sol";
import { IERC1155Items, IERC1155ItemsFunctions } from "./IERC1155Items.sol";

/**
 * An implementation of ERC-1155 capable of minting when role provided.
 */
contract ERC1155Items is ERC1155BaseToken, IERC1155Items {

    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /**
     * Initialize the contract.
     * @param owner Owner address
     * @param tokenName Token name
     * @param tokenBaseURI Base URI for token metadata
     * @param tokenContractURI Contract URI for token metadata
     * @param royaltyReceiver Address of who should be sent the royalty payment
     * @param royaltyFeeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @param implicitModeValidator The implicit mode validator address
     * @param implicitModeProjectId The implicit mode project id
     * @dev This should be called immediately after deployment.
     */
    function initialize(
        address owner,
        string memory tokenName,
        string memory tokenBaseURI,
        string memory tokenContractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        address implicitModeValidator,
        bytes32 implicitModeProjectId
    ) public virtual {
        ERC1155BaseToken._initialize(
            owner, tokenName, tokenBaseURI, tokenContractURI, implicitModeValidator, implicitModeProjectId
        );
        _setDefaultRoyalty(royaltyReceiver, royaltyFeeNumerator);

        _grantRole(MINTER_ROLE, owner);
    }

    //
    // Minting
    //

    /**
     * Mint tokens.
     * @param to Address to mint tokens to.
     * @param tokenId Token ID to mint.
     * @param amount Amount of tokens to mint.
     * @param data Data to pass if receiver is contract.
     */
    function mint(address to, uint256 tokenId, uint256 amount, bytes memory data) external onlyRole(MINTER_ROLE) {
        _mint(to, tokenId, amount, data);
    }

    /**
     * Mint tokens.
     * @param to Address to mint tokens to.
     * @param tokenIds Token IDs to mint.
     * @param amounts Amounts of tokens to mint.
     * @param data Data to pass if receiver is contract.
     */
    function batchMint(
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyRole(MINTER_ROLE) {
        _batchMint(to, tokenIds, amounts, data);
    }

    //
    // Views
    //

    /**
     * Check interface support.
     * @param interfaceId Interface id
     * @return True if supported
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155BaseToken) returns (bool) {
        return type(IERC1155ItemsFunctions).interfaceId == interfaceId
            || ERC1155BaseToken.supportsInterface(interfaceId) || super.supportsInterface(interfaceId);
    }

}
