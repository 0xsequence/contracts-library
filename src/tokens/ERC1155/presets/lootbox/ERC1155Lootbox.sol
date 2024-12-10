// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC1155Lootbox, IERC1155LootboxFunctions} from "./IERC1155Lootbox.sol";
import {ERC1155Items} from "@0xsequence/contracts-library/tokens/ERC1155/presets/items/ERC1155Items.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IERC1155ItemsFunctions} from "@0xsequence/contracts-library/tokens/ERC1155/presets/items/IERC1155Items.sol";

contract ERC1155Lootbox is ERC1155Items, IERC1155Lootbox {
    bytes32 public merkleRoot;
    uint256 public boxSupply;

    mapping(address => uint256) private _commitments;
    mapping(uint256 => bool) private _claimedIdxs;

    constructor() ERC1155Items() {}

    function setBoxContent(bytes32 _merkleRoot, uint256 _boxSupply) external onlyRole(DEFAULT_ADMIN_ROLE) {
        merkleRoot = _merkleRoot;
        boxSupply = _boxSupply;
    }

    function commit() external {
        if (balanceOf(msg.sender, 1) == 0) {
            revert NoBalance();
        }
        _safeTransferFrom(msg.sender, address(this), 1, 1);
        _commitments[msg.sender] = block.number + 1;
        emit Commit(msg.sender);
    }

    function getRevealId(address user) public view returns (uint256 revealIdx) {
        revealIdx = uint256(keccak256(abi.encode(blockhash(_commitments[user]), user))) % boxSupply;

        uint256 iterations;

        while (_claimedIdxs[revealIdx]) {
            revealIdx++;
            if (revealIdx >= boxSupply) revealIdx = 0;
            iterations++;
            if (iterations == boxSupply) break;
        }
    }

    function reveal(address user, BoxContent calldata boxContent, bytes32[] calldata proof) external {
        if (uint256(blockhash(_commitments[user])) == 0) {
            revert InvalidCommit();
        }

        uint256 revealIdx = getRevealId(user);
        bytes32 leaf = keccak256(abi.encode(revealIdx, boxContent));

        if (!MerkleProof.verify(proof, merkleRoot, leaf)) {
            revert InvalidProof();
        }

        for (uint256 i = 0; i < boxContent.tokenAddresses.length; i++) {
            IERC1155ItemsFunctions(boxContent.tokenAddresses[i]).mint(
                user, boxContent.tokenIds[i], boxContent.amounts[i], ""
            );
        }

        delete _commitments[user];
        _claimedIdxs[revealIdx] = true;
        burn(1, 1);
    }

    function refundBox() external {
        if (uint256(blockhash(_commitments[msg.sender])) == 0 && _commitments[msg.sender] > 0) {
            delete _commitments[msg.sender];
            safeTransferFrom(address(this), msg.sender, 1, 1, "");
        }
    }

    // Views
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return type(IERC1155LootboxFunctions).interfaceId == interfaceId || super.supportsInterface(interfaceId);
    }
}
