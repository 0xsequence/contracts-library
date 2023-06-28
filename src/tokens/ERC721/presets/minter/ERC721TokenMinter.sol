// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {ERC721Token} from "@0xsequence/contracts-library/tokens/ERC721/ERC721Token.sol";
import {ERC721TokenMinterErrors} from "@0xsequence/contracts-library/tokens/ERC721/presets/minter/ERC721TokenMinterErrors.sol";

/**
 * A ready made implementation of ERC-721 with role based minting.
 */
contract ERC721TokenMinter is ERC721Token, ERC721TokenMinterErrors {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address private immutable _initializer;
    bool private _initialized;

    /**
     * Deploy contract.
     */
    constructor() ERC721Token() {
        _initializer = msg.sender;
    }

    /**
     * Initialize contract.
     * @param owner The owner of the contract
     * @param tokenName Name of the token
     * @param tokenSymbol Symbol of the token
     * @param tokenBaseURI Base URI of the token
     * @dev This should be called immediately after deployment.
     */
    function initialize(address owner, string memory tokenName, string memory tokenSymbol, string memory tokenBaseURI)
        public
        virtual
        override
    {
        if (msg.sender != _initializer || _initialized) {
            revert InvalidInitialization();
        }

        ERC721Token.initialize(owner, tokenName, tokenSymbol, tokenBaseURI);

        _setupRole(MINTER_ROLE, owner);

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
}
