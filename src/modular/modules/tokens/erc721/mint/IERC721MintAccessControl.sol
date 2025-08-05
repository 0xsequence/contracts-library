// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IModule } from "../../../../interfaces/IModule.sol";

/// @title IERC721MintAccessControl
/// @author Michael Standen
/// @notice Interface for the ERC721MintAccessControl module.
interface IERC721MintAccessControl is IModule {

    /// @notice Mint a token
    /// @param to The address to mint the token to
    /// @param tokenId The ID of the token to mint
    /// @dev The caller must have the mint role
    function mint(address to, uint256 tokenId) external;

    /// @notice Mint a sequential token
    /// @param to The address to mint the token to
    /// @param amount The amount of tokens to mint
    /// @dev The caller must have the mint role
    function mintSequential(address to, uint256 amount) external;

}
