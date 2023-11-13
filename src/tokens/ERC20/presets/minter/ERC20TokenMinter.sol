// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ERC20Token} from "@0xsequence/contracts-library/tokens/ERC20/ERC20Token.sol";
import {
    IERC20TokenMinter,
    IERC20TokenMinterFunctions
} from "@0xsequence/contracts-library/tokens/ERC20/presets/minter/IERC20TokenMinter.sol";

/**
 * A ready made implementation of ERC-20 capable of minting when role provided.
 */
contract ERC20TokenMinter is ERC20Token, IERC20TokenMinter {
    bytes32 internal constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address private immutable _initializer;
    bool private _initialized;

    constructor() {
        _initializer = msg.sender;
    }

    /**
     * Initialize contract.
     * @param owner The owner of the contract
     * @param tokenName Name of the token
     * @param tokenSymbol Symbol of the token
     * @param tokenDecimals Number of decimals
     * @dev This should be called immediately after deployment.
     */
    function initialize(address owner, string memory tokenName, string memory tokenSymbol, uint8 tokenDecimals)
        public
        virtual
        override
    {
        if (msg.sender != _initializer || _initialized) {
            revert InvalidInitialization();
        }

        ERC20Token.initialize(owner, tokenName, tokenSymbol, tokenDecimals);

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
     * @notice This function can only be called by a minter.
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    //
    // Admin
    //

    /**
     * Set name and symbol of token.
     * @param tokenName Name of token.
     * @param tokenSymbol Symbol of token.
     */
    function setNameAndSymbol(string memory tokenName, string memory tokenSymbol)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _tokenName = tokenName;
        _tokenSymbol = tokenSymbol;
    }

    //
    // Views
    //

    /**
     * Check interface support.
     * @param interfaceId Interface id
     * @return True if supported
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return type(IERC20TokenMinterFunctions).interfaceId == interfaceId || ERC20Token.supportsInterface(interfaceId)
            || super.supportsInterface(interfaceId);
    }
}
