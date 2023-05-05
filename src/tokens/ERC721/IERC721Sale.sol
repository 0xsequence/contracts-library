// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

interface IERC721Sale {
    event SaleDetailsUpdated(uint256 supplyCap, uint256 cost, address paymentToken, uint64 startTime, uint64 endTime);

    struct SaleDetails {
        uint256 supplyCap; // 0 supply cap indicates unlimited supply
        uint256 cost;
        address paymentToken; // ERC20 token address for payment. address(0) indicated payment in ETH.
        uint64 startTime;
        uint64 endTime; // 0 end time indicates sale inactive
    }

    /**
     * Get sale details.
     * @return Sale details.
     */
    function saleDetails() external view returns (SaleDetails memory);

    /**
     * Mint tokens.
     * @param _to Address to mint tokens to.
     * @param _amount Amount of tokens to mint.
     * @notice Sale must be active for all tokens.
     */
    function mint(address _to, uint256 _amount) external payable;
}
