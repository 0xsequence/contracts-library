// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IERC1155LootboxFunctions {
    struct BoxContent {
        address[] tokenAddresses;
        uint256[] tokenIds;
        uint256[] amounts;
    }

    /**
     * Set all possible box contents.
     * @param _merkleRoot merkle root built from all possible box contents.
     * @param _boxSupply total amount of boxes.
     * @dev Updating these values before all the boxes have been opened may lead to undesirable behavior.
     */
    function setBoxContent(bytes32 _merkleRoot, uint256 _boxSupply) external;

    /**
     * Get random reveal index.
     * @param user address of reward recipient.
     */
    function getRevealId(address user) external view returns (uint256);

    /**
     * Commit to reveal box content.
     * @notice this function burns user's box.
     */
    function commit() external;

    /**
     * Reveal box content.
     * @param user address of reward recipient.
     * @param boxContent reward selected with random index.
     * @param proof Box contents merkle proof.
     */
    function reveal(address user, BoxContent calldata boxContent, bytes32[] calldata proof) external;

    /**
     * Ask for box refund after commit expiration.
     * @param user address of box owner.
     * @notice this function mints a box for the user when his commit is expired.
     */
    function refundBox(address user) external;
}

interface IERC1155LootboxSignals {
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
     * All boxes opened.
     */
    error AllBoxesOpened();

    /// @notice Emits when a user make a commitment
    event Commit(address user, uint256 blockNumber);
}

// solhint-disable-next-line no-empty-blocks
interface IERC1155Lootbox is IERC1155LootboxFunctions, IERC1155LootboxSignals {}
