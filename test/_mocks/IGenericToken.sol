// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IGenericToken {

    function mint(address to, uint256 tokenId, uint256 amount) external;

    function approve(address owner, address operator, uint256 tokenId, uint256 amount) external;

    function balanceOf(address owner, uint256 tokenId) external view returns (uint256);

}
