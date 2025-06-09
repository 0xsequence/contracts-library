// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { ERC721BaseToken } from "../../ERC721BaseToken.sol";
import { IERC721Items, IERC721ItemsFunctions } from "./IERC721Items.sol";

/**
 * An implementation of ERC-721 capable of minting when role provided.
 */
contract ERC721Items is ERC721BaseToken, IERC721Items {

    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address private immutable _initializer;
    bool private _initialized;

    /**
     * Deploy contract.
     */
    constructor() ERC721BaseToken() {
        _initializer = msg.sender;
    }

    /**
     * Initialize contract.
     * @param owner The owner of the contract
     * @param tokenName Name of the token
     * @param tokenSymbol Symbol of the token
     * @param tokenBaseURI Base URI of the token
     * @param tokenContractURI Contract URI of the token
     * @param royaltyReceiver Address of who should be sent the royalty payment
     * @param royaltyFeeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @param implicitModeValidator The implicit mode validator address
     * @param implicitModeProjectId The implicit mode project id
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
        address implicitModeValidator,
        bytes32 implicitModeProjectId
    ) public virtual {
        if (msg.sender != _initializer || _initialized) {
            revert InvalidInitialization();
        }

        ERC721BaseToken._initialize(
            owner, tokenName, tokenSymbol, tokenBaseURI, tokenContractURI, implicitModeValidator, implicitModeProjectId
        );
        _setDefaultRoyalty(royaltyReceiver, royaltyFeeNumerator);

        _grantRole(MINTER_ROLE, owner);

        _initialized = true;
    }

    //
    // Minting
    //

    /**
     * Mint tokens.
     * @param to Address to mint tokens to.
     * @param amount Amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
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
    ) public view virtual override returns (bool) {
        return type(IERC721ItemsFunctions).interfaceId == interfaceId || super.supportsInterface(interfaceId);
    }

}
