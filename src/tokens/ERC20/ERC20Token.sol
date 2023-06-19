// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

error InvalidInitialization();

/**
 * A ready made implementation of ERC-20.
 */
contract ERC20Token is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    string private _tokenName;
    string private _tokenSymbol;
    uint8 private _tokenDecimals;

    address private immutable _initializer;
    bool private _initialized;

    /**
     * Deploy contract.
     */
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
    function initialize(address owner, string memory tokenName, string memory tokenSymbol, uint8 tokenDecimals) external {
        if (msg.sender != _initializer || _initialized) {
            revert InvalidInitialization();
        }
        _initialized = true;

        _tokenName = tokenName;
        _tokenSymbol = tokenSymbol;
        _tokenDecimals = tokenDecimals;

        _setupRole(DEFAULT_ADMIN_ROLE, owner);
        _setupRole(MINTER_ROLE, owner);
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
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IERC20).interfaceId || interfaceId == type(IERC20Metadata).interfaceId
            || AccessControl.supportsInterface(interfaceId) || super.supportsInterface(interfaceId);
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
