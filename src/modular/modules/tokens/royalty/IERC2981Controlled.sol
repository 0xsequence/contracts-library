// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// @title IERC2981Controlled
/// @author Michael Standen
/// @notice NFT Royalty interface that allows updates
interface IERC2981Controlled {

    /// @notice Sets the default royalty information
    /// @param receiver The address to pay the royalty to
    /// @param royaltyBps The royalty fraction in basis points
    function setDefaultRoyalty(address receiver, uint96 royaltyBps) external;

    /// @notice Sets the royalty information for a specific token id
    /// @param tokenId The token id to set the royalty information for
    /// @param receiver The address to pay the royalty to
    /// @param royaltyBps The royalty fraction in basis points
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 royaltyBps) external;

}
