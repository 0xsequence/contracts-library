// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { SignalsImplicitModeControlled } from "../common/SignalsImplicitModeControlled.sol";

import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import { IERC20 } from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

error InvalidInitialization();

/**
 * A standard base implementation of ERC-20 for use in Sequence library contracts.
 */
abstract contract ERC20BaseToken is ERC20, SignalsImplicitModeControlled {

    string internal _tokenName;
    string internal _tokenSymbol;
    uint8 private _tokenDecimals;

    bool private _initialized;

    constructor() ERC20("", "") { }

    /**
     * Initialize contract.
     * @param owner The owner of the contract
     * @param tokenName Name of the token
     * @param tokenSymbol Symbol of the token
     * @param tokenDecimals Number of decimals
     * @param implicitModeValidator Implicit session validator address
     * @param implicitModeProjectId Implicit session project id
     * @dev This should be called immediately after deployment.
     */
    function initialize(
        address owner,
        string memory tokenName,
        string memory tokenSymbol,
        uint8 tokenDecimals,
        address implicitModeValidator,
        bytes32 implicitModeProjectId
    ) public virtual {
        if (_initialized) {
            revert InvalidInitialization();
        }

        _tokenName = tokenName;
        _tokenSymbol = tokenSymbol;
        _tokenDecimals = tokenDecimals;

        _grantRole(DEFAULT_ADMIN_ROLE, owner);

        _initializeImplicitMode(owner, implicitModeValidator, implicitModeProjectId);

        _initialized = true;
    }

    //
    // Burn
    //

    /**
     * Allows the owner of the token to burn their tokens.
     * @param amount Amount of tokens to burn
     */
    function burn(
        uint256 amount
    ) public virtual {
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
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return interfaceId == type(IERC20).interfaceId || interfaceId == type(IERC20Metadata).interfaceId
            || super.supportsInterface(interfaceId);
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
