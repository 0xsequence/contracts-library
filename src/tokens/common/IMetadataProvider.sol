// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IMetadataProvider {

    /**
     * Provides the metadata for the given token.
     * @param tokenAddress The address of the token.
     * @param tokenId The ID of the token.
     */
    function metadata(address tokenAddress, uint256 tokenId) external view returns (string memory);

}
