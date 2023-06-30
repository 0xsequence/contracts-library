// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

interface IERC721Sale {
    event SaleDetailsUpdated(uint256 supplyCap, uint256 cost, address paymentToken, uint64 startTime, uint64 endTime, bytes32 merkleRoot);

    struct SaleDetails {
        uint256 supplyCap; // 0 supply cap indicates unlimited supply
        uint256 cost;
        address paymentToken; // ERC20 token address for payment. address(0) indicated payment in ETH.
        uint64 startTime;
        uint64 endTime; // 0 end time indicates sale inactive
        bytes32 merkleRoot; // Root of allowed addresses
    }

    /**
     * Get sale details.
     * @return Sale details.
     */
    function saleDetails() external view returns (SaleDetails memory);

    /**
     * Mint tokens.
     * @param to Address to mint tokens to.
     * @param amount Amount of tokens to mint.
     * @param proof Merkle proof for allowlist minting.
     * @notice Sale must be active for all tokens.
     * @dev An empty proof is supplied when no proof is required.
     */
    function mint(address to, uint256 amount, bytes32[] memory proof) external payable;
}
