// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC1155Lootbox, IERC1155LootboxFunctions} from "./IERC1155Lootbox.sol";
import {ERC1155Items} from "@0xsequence/contracts-library/tokens/ERC1155/presets/items/ERC1155Items.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IERC1155ItemsFunctions} from "@0xsequence/contracts-library/tokens/ERC1155/presets/items/IERC1155Items.sol";

contract ERC1155Lootbox is ERC1155Items, IERC1155Lootbox {
    bytes32 internal constant MINT_ADMIN_ROLE = keccak256("MINT_ADMIN_ROLE");

    bytes32 public merkleRoot;
    uint256 public boxSupply;

    mapping(address => uint256) internal _commitments;
    mapping(uint256 => bool) internal _claimedIdxs;

    constructor() ERC1155Items() {}

    /// @inheritdoc ERC1155Items
    function initialize(
        address owner,
        string memory tokenName,
        string memory tokenBaseURI,
        string memory tokenContractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) public virtual override {
        _grantRole(MINT_ADMIN_ROLE, owner);
        super.initialize(owner, tokenName, tokenBaseURI, tokenContractURI, royaltyReceiver, royaltyFeeNumerator);
    }

    /// @inheritdoc IERC1155LootboxFunctions
    function setBoxContent(bytes32 _merkleRoot, uint256 _boxSupply) external onlyRole(MINT_ADMIN_ROLE) {
        merkleRoot = _merkleRoot;
        boxSupply = _boxSupply;
    }

    /// @inheritdoc IERC1155LootboxFunctions
    function commit() external {
        if (_commitments[msg.sender] != 0) {
            revert PendingReveal();
        }
        if (balanceOf(msg.sender, 1) == 0) {
            revert NoBalance();
        }
        _burn(msg.sender, 1, 1);
        uint256 revealAfterBlock = block.number + 1;
        _commitments[msg.sender] = revealAfterBlock;

        emit Commit(msg.sender, revealAfterBlock);
    }

    /// @inheritdoc IERC1155LootboxFunctions
    function reveal(address user, BoxContent calldata boxContent, bytes32[] calldata proof) external {
        uint256 revealIdx = getRevealId(user);
        bytes32 leaf = keccak256(abi.encode(revealIdx, boxContent));

        if (!MerkleProof.verify(proof, merkleRoot, leaf)) {
            revert InvalidProof();
        }

        delete _commitments[user];
        _claimedIdxs[revealIdx] = true;

        for (uint256 i = 0; i < boxContent.tokenAddresses.length; i++) {
            IERC1155ItemsFunctions(boxContent.tokenAddresses[i]).mint(
                user, boxContent.tokenIds[i], boxContent.amounts[i], ""
            );
        }
    }

    /// @inheritdoc IERC1155LootboxFunctions
    function refundBox(address user) external {
        if (_commitments[user] == 0) {
            revert NoCommit();
        }
        if (uint256(blockhash(_commitments[user])) != 0 || block.number <= _commitments[user]) {
            revert PendingReveal();
        }
        delete _commitments[user];
        _mint(user, 1, 1, "");
    }

    /// @inheritdoc IERC1155LootboxFunctions
    function getRevealId(address user) public view returns (uint256 revealIdx) {
        if (_commitments[user] == 0) {
            revert NoCommit();
        }

        bytes32 blockHash = blockhash(_commitments[user]);

        if (uint256(blockHash) == 0) {
            revert InvalidCommit();
        }

        revealIdx = uint256(keccak256(abi.encode(blockHash, user))) % boxSupply;

        uint256 iterations;

        while (_claimedIdxs[revealIdx]) {
            revealIdx++;
            if (revealIdx >= boxSupply) revealIdx = 0;
            iterations++;
            if (iterations == boxSupply) {
                revert AllBoxesOpened();
            }
        }
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return type(IERC1155LootboxFunctions).interfaceId == interfaceId || super.supportsInterface(interfaceId);
    }
}
