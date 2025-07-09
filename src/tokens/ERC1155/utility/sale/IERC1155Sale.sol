// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IERC1155SaleFunctions {

    struct GlobalSaleDetails {
        uint256 minTokenId;
        uint256 maxTokenId;
        uint256 cost;
        uint256 remainingSupply;
        uint64 startTime;
        uint64 endTime; // 0 end time indicates sale inactive
        bytes32 merkleRoot; // Root of allowed addresses
    }

    struct SaleDetails {
        uint256 cost;
        uint256 remainingSupply;
        uint64 startTime;
        uint64 endTime; // 0 end time indicates sale inactive
        bytes32 merkleRoot; // Root of allowed addresses
    }

    /**
     * Get global sales details.
     * @return Sale details.
     * @notice Global sales details apply to all tokens.
     * @notice Global sales details are overriden when token sale is active.
     */
    function globalSaleDetails() external view returns (GlobalSaleDetails memory);

    /**
     * Get token sale details.
     * @param tokenId Token ID to get sale details for.
     * @return Sale details.
     * @notice Token sale details override global sale details.
     */
    function tokenSaleDetails(
        uint256 tokenId
    ) external view returns (SaleDetails memory);

    /**
     * Get sale details for multiple tokens.
     * @param tokenIds Array of token IDs to retrieve sale details for.
     * @return Array of sale details corresponding to each token ID.
     * @notice Each token's sale details override the global sale details if set.
     */
    function tokenSaleDetailsBatch(
        uint256[] calldata tokenIds
    ) external view returns (SaleDetails[] memory);

    /**
     * Get payment token.
     * @return Payment token address.
     * @notice address(0) indicates payment in ETH.
     */
    function paymentToken() external view returns (address);

    /**
     * Mint tokens.
     * @param to Address to mint tokens to.
     * @param tokenIds Token IDs to mint.
     * @param amounts Amounts of tokens to mint.
     * @param data Data to pass if receiver is contract.
     * @param paymentToken ERC20 token address to accept payment in. address(0) indicates ETH.
     * @param maxTotal Maximum amount of payment tokens.
     * @param proof Merkle proof for allowlist minting.
     * @notice Sale must be active for all tokens.
     * @dev tokenIds must be sorted ascending without duplicates.
     * @dev An empty proof is supplied when no proof is required.
     */
    function mint(
        address to,
        uint256[] memory tokenIds,
        uint256[] memory amounts,
        bytes memory data,
        address paymentToken,
        uint256 maxTotal,
        bytes32[] calldata proof
    ) external payable;

}

interface IERC1155SaleSignals {

    event GlobalSaleDetailsUpdated(
        uint256 minTokenId,
        uint256 maxTokenId,
        uint256 cost,
        uint256 remainingSupply,
        uint64 startTime,
        uint64 endTime,
        bytes32 merkleRoot
    );
    event TokenSaleDetailsUpdated(
        uint256 tokenId, uint256 cost, uint256 remainingSupply, uint64 startTime, uint64 endTime, bytes32 merkleRoot
    );
    event ItemsMinted(address to, uint256[] tokenIds, uint256[] amounts);

    /**
     * Contract already initialized.
     */
    error InvalidInitialization();

    /**
     * Sale details supplied are invalid.
     */
    error InvalidSaleDetails();

    /**
     * Sale is not active globally.
     */
    error GlobalSaleInactive();

    /**
     * Sale is not active.
     * @param tokenId Invalid Token ID.
     */
    error SaleInactive(uint256 tokenId);

    /**
     * Insufficient tokens for payment.
     * @param currency Currency address. address(0) indicates ETH.
     * @param expected Expected amount of tokens.
     * @param actual Actual amount of tokens.
     */
    error InsufficientPayment(address currency, uint256 expected, uint256 actual);

    /**
     * Invalid token IDs.
     */
    error InvalidTokenIds();

    /**
     * Insufficient supply of tokens.
     * @param remainingSupply Remaining supply.
     * @param amount Amount to mint.
     */
    error InsufficientSupply(uint256 remainingSupply, uint256 amount);

}

interface IERC1155Sale is IERC1155SaleFunctions, IERC1155SaleSignals { }
