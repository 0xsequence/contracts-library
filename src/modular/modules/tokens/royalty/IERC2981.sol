// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// @title IERC2981
/// @notice Interface for the NFT Royalty Standard
interface IERC2981 {

    /// @notice Returns how much royalty is owed and to whom, based on a sale price that may be denominated in any unit of
    /// exchange. The royalty amount is denominated and should be paid in that same unit of exchange.
    /// @param tokenId The token id to get the royalty for
    /// @param salePrice The sale price to get the royalty for
    /// @return receiver The address to pay the royalty to
    /// @return royaltyAmount The amount of royalty to pay
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view returns (address receiver, uint256 royaltyAmount);

}
