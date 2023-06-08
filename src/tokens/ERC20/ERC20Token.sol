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

    string private tokenName;
    string private tokenSymbol;
    uint8 private tokenDecimals;

    address private immutable initializer;
    bool private initialized;

    /**
     * Deploy contract.
     */
    constructor() ERC20("", "") {
        initializer = msg.sender;
    }

    /**
     * Initialize contract.
     * @param owner The owner of the contract
     * @param tokenName_ Name of the token
     * @param tokenSymbol_ Symbol of the token
     * @param tokenDecimals_ Number of decimals
     * @dev This should be called immediately after deployment.
     */
    function initialize(address owner, string memory tokenName_, string memory tokenSymbol_, uint8 tokenDecimals_) external {
        if (msg.sender != initializer || initialized) {
            revert InvalidInitialization();
        }
        initialized = true;

        tokenName = tokenName_;
        tokenSymbol = tokenSymbol_;
        tokenDecimals = tokenDecimals_;

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
        return tokenName;
    }

    /**
     * Override the ERC20 symbol function.
     */
    function symbol() public view override returns (string memory) {
        return tokenSymbol;
    }

    /**
     * Override the ERC20 decimals function.
     */
    function decimals() public view override returns (uint8) {
        return tokenDecimals;
    }
}
