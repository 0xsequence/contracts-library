// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IERC1155 } from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import { IERC1155Receiver, IERC165 } from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";

/**
 * An ERC-1155 contract that allows permissive minting.
 */
contract ERC1155Holder is IERC1155Receiver {

    /// @dev Emitted when a claim is added.
    event ClaimAdded(address claimant, address tokenAddress, uint256 tokenId, uint256 amount);
    /// @dev Emitted when a batch of claims is added.
    event ClaimAddedBatch(address claimant, address tokenAddress, uint256[] tokenIds, uint256[] amounts);

    /// @dev Emitted when a claim is claimed.
    event Claimed(address claimant, address tokenAddress, uint256 tokenId, uint256 amount);
    /// @dev Emitted when a batch of claims is claimed.
    event ClaimedBatch(address claimant, address tokenAddress, uint256[] tokenIds, uint256[] amounts);

    /// @dev Error thrown when the claimant is invalid.
    error InvalidClaimant();

    /// @dev claimant -> tokenAddress -> tokenId -> amount
    mapping(address => mapping(address => mapping(uint256 => uint256))) public claims;

    /// @dev Claims a token.
    /// @param claimant The claimant.
    /// @param tokenAddress The token address.
    /// @param tokenId The token id.
    function claim(address claimant, address tokenAddress, uint256 tokenId) public {
        uint256 amount = claims[claimant][tokenAddress][tokenId];
        delete claims[claimant][tokenAddress][tokenId];
        emit Claimed(claimant, tokenAddress, tokenId, amount);
        IERC1155(tokenAddress).safeTransferFrom(address(this), claimant, tokenId, amount, "");
    }

    /// @dev Claims a batch of tokens.
    /// @param claimant The claimant.
    /// @param tokenAddress The token address.
    /// @param tokenIds The token ids.
    function claimBatch(address claimant, address tokenAddress, uint256[] memory tokenIds) public {
        uint256[] memory amounts = new uint256[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            amounts[i] = claims[claimant][tokenAddress][tokenIds[i]];
            delete claims[claimant][tokenAddress][tokenIds[i]];
        }
        emit ClaimedBatch(claimant, tokenAddress, tokenIds, amounts);
        IERC1155(tokenAddress).safeBatchTransferFrom(address(this), claimant, tokenIds, amounts, "");
    }

    /// @inheritdoc IERC1155Receiver
    /// @param claimData The encoded claimant.
    function onERC1155Received(
        address,
        address,
        uint256 tokenId,
        uint256 amount,
        bytes calldata claimData
    ) public virtual override returns (bytes4) {
        address claimant = _decodeClaimant(claimData);
        address tokenAddress = msg.sender;
        claims[claimant][tokenAddress][tokenId] += amount;
        emit ClaimAdded(claimant, tokenAddress, tokenId, amount);
        return this.onERC1155Received.selector;
    }

    /// @inheritdoc IERC1155Receiver
    /// @param claimData The encoded claimant.
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata tokenIds,
        uint256[] calldata amounts,
        bytes calldata claimData
    ) public virtual override returns (bytes4) {
        address claimant = _decodeClaimant(claimData);
        address tokenAddress = msg.sender;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            claims[claimant][tokenAddress][tokenIds[i]] += amounts[i];
        }
        emit ClaimAddedBatch(claimant, tokenAddress, tokenIds, amounts);
        return this.onERC1155BatchReceived.selector;
    }

    /// @dev Decodes the claimant from the claim data.
    function _decodeClaimant(
        bytes calldata claimData
    ) internal pure returns (address claimant) {
        if (claimData.length == 20) {
            // Packed address format
            assembly {
                calldatacopy(0, claimData.offset, 20)
                claimant := shr(96, mload(0))
            }
        } else if (claimData.length == 32) {
            // ABI encoded address format
            (claimant) = abi.decode(claimData, (address));
        }
        if (claimant == address(0)) {
            revert InvalidClaimant();
        }
        return claimant;
    }

    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(IERC165) returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || interfaceId == type(IERC165).interfaceId;
    }

}
