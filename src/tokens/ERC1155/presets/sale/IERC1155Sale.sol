// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

interface IERC1155Sale {
    event GlobalSaleDetailsUpdated(uint256 cost, uint256 supplyCap, uint64 startTime, uint64 endTime);
    event TokenSaleDetailsUpdated(uint256 tokenId, uint256 cost, uint256 supplyCap, uint64 startTime, uint64 endTime);

    struct SaleDetails {
        uint256 cost;
        uint64 startTime;
        uint64 endTime; // 0 end time indicates sale inactive
    }

    /**
     * Get global sales details.
     * @return Sale details.
     * @notice Global sales details apply to all tokens.
     * @notice Global sales details are overriden when token sale is active.
     */
    function globalSaleDetails() external returns (SaleDetails memory);

    /**
     * Get token sale details.
     * @param _tokenId Token ID to get sale details for.
     * @return Sale details.
     * @notice Token sale details override global sale details.
     */
    function tokenSaleDetails(uint256 _tokenId) external returns (SaleDetails memory);

    /**
     * Get payment token.
     * @return Payment token address.
     * @notice address(0) indicates payment in ETH.
     */
    function paymentToken() external returns (address);

    /**
     * Mint tokens.
     * @param _to Address to mint tokens to.
     * @param _tokenIds Token IDs to mint.
     * @param _amounts Amounts of tokens to mint.
     * @param _data Data to pass if receiver is contract.
     * @notice Sale must be active for all tokens.
     */
    function mint(address _to, uint256[] memory _tokenIds, uint256[] memory _amounts, bytes memory _data)
        external
        payable;
}
