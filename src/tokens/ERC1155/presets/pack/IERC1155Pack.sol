// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IERC1155Pack {

    struct PackContent {
        address[] tokenAddresses;
        bool[] isERC721;
        uint256[][] tokenIds;
        uint256[][] amounts;
    }

    /**
     * Commit expired or never made.
     */
    error InvalidCommit();

    /**
     * Reveal is pending.
     */
    error PendingReveal();

    /**
     * Commit never made.
     */
    error NoCommit();

    /**
     * No balance.
     */
    error NoBalance();

    /**
     * Invalid proof.
     */
    error InvalidProof();

    /**
     * All packs opened.
     */
    error AllPacksOpened();

    /// @notice Emitted when a user make a commitment
    event Commit(address indexed user, uint256 packId);

    /// @notice Emitted when a reveal is successful
    event Reveal(address user, uint256 packId);

    /**
     * Set all possible pack contents.
     * @param _merkleRoot merkle root built from all possible pack contents.
     * @param _supply total amount of packs.
     * @param packId tokenId of pack.
     * @dev Updating these values before all the packs have been opened may lead to undesirable behavior.
     */
    function setPacksContent(bytes32 _merkleRoot, uint256 _supply, uint256 packId) external;

    /**
     * Get random reveal index.
     * @param user address of reward recipient.
     * @param packId tokenId of pack.
     */
    function getRevealIdx(address user, uint256 packId) external view returns (uint256);

    /**
     * Commit to reveal pack content.
     * @param packId tokenId of pack.
     * @notice this function burns user's pack.
     */
    function commit(
        uint256 packId
    ) external;

    /**
     * Reveal pack content.
     * @param user address of reward recipient.
     * @param packContent reward selected with random index.
     * @param proof Pack contents merkle proof.
     * @param packId tokenId of pack.
     */
    function reveal(
        address user,
        PackContent calldata packContent,
        bytes32[] calldata proof,
        uint256 packId
    ) external;

    /**
     * Ask for pack refund after commit expiration.
     * @param user address of pack owner.
     * @param packId tokenId of pack.
     * @notice this function mints a pack for the user when his commit is expired.
     */
    function refundPack(address user, uint256 packId) external;

}
