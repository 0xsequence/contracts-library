// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// A minimal implementation of the ERC721 transfer interface.
interface IERC721Transfer {
    function transferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}
