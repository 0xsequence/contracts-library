// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ERC1155MintBurn, ERC1155} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155MintBurn.sol";
import {
    IERC1155PermissiveMinter, 
    IERC1155PermissiveMinterFunctions
} from "@0xsequence/contracts-library/tokens/ERC1155/presets/sale/IERC1155PermissiveMinter.sol";
import {ERC1155BaseToken} from "@0xsequence/contracts-library/tokens/ERC1155/ERC1155BaseToken.sol";

/**
 * An ERC-1155 contract that allows permissive minting.
 */
contract ERC1155PermissiveMinter is ERC1155MintBurn, ERC1155BaseToken, IERC1155PermissiveMinter {

    address private immutable initializer;
    bool private initialized;

    constructor() {
        initializer = msg.sender;
    }

    /**
     * Initialize the contract.
     * @param owner Owner address
     * @param tokenName Token name
     * @param tokenBaseURI Base URI for token metadata
     * @param tokenContractURI Contract URI for token metadata
     * @param royaltyReceiver Address of who should be sent the royalty payment
     * @param royaltyFeeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @dev This should be called immediately after deployment.
     */
    function initialize(
        address owner,
        string memory tokenName,
        string memory tokenBaseURI,
        string memory tokenContractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    )
        public
        virtual
    {
        if (msg.sender != initializer || initialized) {
            revert InvalidInitialization();
        }

        ERC1155BaseToken._initialize(owner, tokenName, tokenBaseURI, tokenContractURI);
        _setDefaultRoyalty(royaltyReceiver, royaltyFeeNumerator);

        initialized = true;
    }

    /**
     * Mint tokens.
     * @param to Address to mint tokens to.
     * @param tokenId Token ID to mint.
     * @param amount Amount of tokens to mint.
     * @param data Data to pass if receiver is contract.
     */
    function mint(address to, uint256 tokenId, uint256 amount, bytes memory data) public {
        _mint(to, tokenId, amount, data);
    }

    //
    // Views
    //

    /**
     * Check interface support.
     * @param interfaceId Interface id
     * @return True if supported
     */
    function supportsInterface(bytes4 interfaceId) public view override (ERC1155BaseToken, ERC1155) returns (bool) {
        return type(IERC1155PermissiveMinterFunctions).interfaceId == interfaceId || ERC1155BaseToken.supportsInterface(interfaceId);
    }

}