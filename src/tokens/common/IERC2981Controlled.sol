// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IERC2981ControlledFunctions {

    /**
     * Sets the royalty information that all ids in this contract will default to.
     * @param receiver Address of who should be sent the royalty payment
     * @param feeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     */
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external;

    /**
     * Sets the royalty information that a given token id in this contract will use.
     * @param tokenId The token id to set the royalty information for
     * @param receiver Address of who should be sent the royalty payment
     * @param feeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @notice This overrides the default royalty information for this token id
     */
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external;

}

interface IERC2981Controlled is IERC2981ControlledFunctions { }
