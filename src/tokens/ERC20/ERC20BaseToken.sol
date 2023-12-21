// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

error InvalidInitialization();

/**
 * A standard base implementation of ERC-20 for use in Sequence library contracts.
 */
abstract contract ERC20BaseToken is ERC20, AccessControlEnumerable {
    string internal _tokenName;
    string internal _tokenSymbol;
    uint8 private _tokenDecimals;

    address private immutable _initializer;
    bool private _initialized;

    constructor() ERC20("", "") {
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
    {
        if (msg.sender != _initializer || _initialized) {
            revert InvalidInitialization();
        }

        _tokenName = tokenName;
        _tokenSymbol = tokenSymbol;
        _tokenDecimals = tokenDecimals;

        _grantRole(DEFAULT_ADMIN_ROLE, owner);

        _initialized = true;
    }

    //
    // Burn
    //

    /**
     * Allows the owner of the token to burn their tokens.
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 amount) public virtual {
        _burn(msg.sender, amount);
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
        return interfaceId == type(IERC20).interfaceId || interfaceId == type(IERC20Metadata).interfaceId
            || AccessControlEnumerable.supportsInterface(interfaceId) || super.supportsInterface(interfaceId);
    }

    //
    // ERC20 Overrides
    //

    /**
     * Override the ERC20 name function.
     */
    function name() public view override returns (string memory) {
        return _tokenName;
    }

    /**
     * Override the ERC20 symbol function.
     */
    function symbol() public view override returns (string memory) {
        return _tokenSymbol;
    }

    /**
     * Override the ERC20 decimals function.
     */
    function decimals() public view override returns (uint8) {
        return _tokenDecimals;
    }
}
