// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IERC1155Sale {

    /**
     * Sale details.
     * @param minTokenId Minimum token ID for this sale. (Inclusive)
     * @param maxTokenId Maximum token ID for this sale. (Inclusive)
     * @param cost Cost per token.
     * @param paymentToken ERC20 token address to accept payment in. address(0) indicates payment in ETH.
     * @param supply Maximum number of tokens that can be minted (per token ID).
     * @param startTime Start time of the sale. (Inclusive)
     * @param endTime End time of the sale. (Inclusive)
     * @param merkleRoot Merkle root for allowlist minting. 0 indicates no proof required.
     */
    struct SaleDetails {
        uint256 minTokenId;
        uint256 maxTokenId;
        uint256 cost;
        address paymentToken;
        uint256 supply;
        uint64 startTime;
        uint64 endTime;
        bytes32 merkleRoot;
    }

    /**
     * Get the total number of sale details.
     * @return Total number of sale details.
     */
    function saleDetailsCount() external view returns (uint256);

    /**
     * Get sale details.
     * @param saleIndex Index of the sale details to get.
     * @return details Sale details.
     */
    function saleDetails(
        uint256 saleIndex
    ) external view returns (SaleDetails memory details);

    /**
     * Get sale details for multiple sale indexes.
     * @param saleIndexes Array of sale indexes to retrieve sale details for.
     * @return details Array of sale details corresponding to each sale index.
     */
    function saleDetailsBatch(
        uint256[] calldata saleIndexes
    ) external view returns (SaleDetails[] memory details);

    /**
     * Add new sale details.
     * @param details Sale details to add.
     * @return saleIndex Index of the newly added sale details.
     */
    function addSaleDetails(
        SaleDetails calldata details
    ) external returns (uint256 saleIndex);

    /**
     * Update existing sale details.
     * @param saleIndex Index of the sale details to update.
     * @param details Sale details to update.
     */
    function updateSaleDetails(uint256 saleIndex, SaleDetails calldata details) external;

    /**
     * Mint tokens.
     * @param to Address to mint tokens to.
     * @param tokenIds Token IDs to mint.
     * @param amounts Amounts of tokens to mint.
     * @param data Data to pass if receiver is contract.
     * @param saleIndexes Sale indexes for each token. Must match tokenIds length.
     * @param expectedPaymentToken ERC20 token address to accept payment in. address(0) indicates ETH.
     * @param maxTotal Maximum amount of payment tokens.
     * @param proofs Merkle proofs for allowlist minting. Must match tokenIds length.
     * @notice Sale must be active for all tokens.
     * @dev All sales must use the same payment token.
     * @dev An empty proof is supplied when no proof is required.
     */
    function mint(
        address to,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts,
        bytes calldata data,
        uint256[] calldata saleIndexes,
        address expectedPaymentToken,
        uint256 maxTotal,
        bytes32[][] calldata proofs
    ) external payable;

    /**
     * Emitted when sale details are added.
     * @param saleIndex Index of the sale details that were added.
     * @param details Sale details that were added.
     */
    event SaleDetailsAdded(uint256 saleIndex, SaleDetails details);

    /**
     * Emitted when sale details are updated.
     * @param saleIndex Index of the sale details that were updated.
     * @param details Sale details that were updated.
     */
    event SaleDetailsUpdated(uint256 saleIndex, SaleDetails details);

    /**
     * Emitted when tokens are minted.
     * @param to Address that minted the tokens.
     * @param tokenIds Token IDs that were minted.
     * @param amounts Amounts of tokens that were minted.
     * @param saleIndexes Sale indexes that were minted from.
     */
    event ItemsMinted(address to, uint256[] tokenIds, uint256[] amounts, uint256[] saleIndexes);

    /**
     * Contract already initialized.
     */
    error InvalidInitialization();

    /**
     * Sale details supplied are invalid.
     */
    error InvalidSaleDetails();

    /**
     * Sale details index does not exist.
     */
    error SaleDetailsNotFound(uint256 index);

    /**
     * Sale is not active.
     */
    error SaleInactive();

    /**
     * Insufficient tokens for payment.
     * @param currency Currency address. address(0) indicates ETH.
     * @param expected Expected amount of tokens.
     * @param actual Actual amount of tokens.
     */
    error InsufficientPayment(address currency, uint256 expected, uint256 actual);

    /**
     * Insufficient supply of tokens.
     * @param remainingSupply Remaining supply.
     * @param amount Amount to mint.
     */
    error InsufficientSupply(uint256 remainingSupply, uint256 amount);

    /**
     * Invalid array lengths.
     */
    error InvalidArrayLengths();

    /**
     * Invalid amount.
     */
    error InvalidAmount();

    /**
     * Payment token mismatch between sales.
     */
    error PaymentTokenMismatch();

}
