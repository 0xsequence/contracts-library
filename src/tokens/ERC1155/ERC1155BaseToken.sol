// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { ERC2981Controlled } from "../common/ERC2981Controlled.sol";
import { SignalsImplicitModeControlled } from "../common/SignalsImplicitModeControlled.sol";
import { ERC1155, ERC1155Supply } from "./extensions/supply/ERC1155Supply.sol";

import { LibString } from "solady/utils/LibString.sol";

error InvalidInitialization();

/**
 * A standard base implementation of ERC-1155 for use in Sequence library contracts.
 */
abstract contract ERC1155BaseToken is ERC1155Supply, ERC2981Controlled, SignalsImplicitModeControlled {

    bytes32 internal constant METADATA_ADMIN_ROLE = keccak256("METADATA_ADMIN_ROLE");

    string public name;
    string public baseURI;
    string public contractURI;

    bool private _initialized;

    /**
     * Initialize the contract.
     * @param owner Owner address.
     * @param tokenName Token name.
     * @param tokenBaseURI Base URI for token metadata.
     * @param tokenContractURI Contract URI for token metadata.
     * @param implicitModeValidator Implicit session validator address.
     * @param implicitModeProjectId Implicit session project id.
     * @dev This should be called immediately after deployment.
     */
    function _initialize(
        address owner,
        string memory tokenName,
        string memory tokenBaseURI,
        string memory tokenContractURI,
        address implicitModeValidator,
        bytes32 implicitModeProjectId
    ) internal {
        if (_initialized) {
            revert InvalidInitialization();
        }

        name = tokenName;
        baseURI = tokenBaseURI;
        contractURI = tokenContractURI;

        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(ROYALTY_ADMIN_ROLE, owner);
        _grantRole(METADATA_ADMIN_ROLE, owner);

        _initializeImplicitMode(owner, implicitModeValidator, implicitModeProjectId);

        _initialized = true;
    }

    //
    // Metadata
    //

    /// @inheritdoc ERC1155
    function uri(
        uint256 _id
    ) public view virtual override returns (string memory) {
        return string(abi.encodePacked(baseURI, LibString.toString(_id), ".json"));
    }

    /**
     * Update the base URI of token's URI.
     * @param tokenBaseURI New base URI of token's URI
     */
    function setBaseMetadataURI(
        string memory tokenBaseURI
    ) external onlyRole(METADATA_ADMIN_ROLE) {
        baseURI = tokenBaseURI;
    }

    /**
     * Update the name of the contract.
     * @param tokenName New contract name
     */
    function setContractName(
        string memory tokenName
    ) external onlyRole(METADATA_ADMIN_ROLE) {
        name = tokenName;
    }

    /**
     * Update the contract URI of token's URI.
     * @param tokenContractURI New contract URI of token's URI
     * @notice Refer to https://docs.opensea.io/docs/contract-level-metadata
     */
    function setContractURI(
        string memory tokenContractURI
    ) external onlyRole(METADATA_ADMIN_ROLE) {
        contractURI = tokenContractURI;
    }

    //
    // Burn
    //

    /**
     * Allows the owner of the token to burn their tokens.
     * @param tokenId Id of token to burn
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 tokenId, uint256 amount) public virtual {
        super._burn(msg.sender, tokenId, amount);
    }

    /**
     * Burn tokens of given token id for each (tokenIds[i], amounts[i]) pair.
     * @param tokenIds Array of token ids to burn
     * @param amounts Array of the amount to be burned
     */
    function batchBurn(uint256[] memory tokenIds, uint256[] memory amounts) public virtual {
        super._batchBurn(msg.sender, tokenIds, amounts);
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
    ) public view virtual override(ERC1155Supply, ERC2981Controlled, SignalsImplicitModeControlled) returns (bool) {
        return ERC1155Supply.supportsInterface(interfaceId) || ERC2981Controlled.supportsInterface(interfaceId)
            || SignalsImplicitModeControlled.supportsInterface(interfaceId);
    }

}
