// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC1155Pack} from "./IERC1155Pack.sol";
import {ERC1155Items} from "@0xsequence/contracts-library/tokens/ERC1155/presets/items/ERC1155Items.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IERC1155ItemsFunctions} from "@0xsequence/contracts-library/tokens/ERC1155/presets/items/IERC1155Items.sol";

contract ERC1155Pack is ERC1155Items, IERC1155Pack {
    bytes32 internal constant PACK_ADMIN_ROLE = keccak256("PACK_ADMIN_ROLE");

    bytes32 public merkleRoot;
    uint256 public supply;
    uint256 public remainingSupply;

    mapping(address => uint256) internal _commitments;
    mapping(uint256 => uint256) internal _availableIndices;

    constructor() ERC1155Items() {}

    /// @inheritdoc IERC1155Pack
    function initialize(
        address owner,
        string memory tokenName,
        string memory tokenBaseURI,
        string memory tokenContractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        bytes32 _merkleRoot,
        uint256 _supply
    ) public virtual {
        _grantRole(PACK_ADMIN_ROLE, owner);
        merkleRoot = _merkleRoot;
        supply = _supply;
        remainingSupply = _supply;
        super.initialize(owner, tokenName, tokenBaseURI, tokenContractURI, royaltyReceiver, royaltyFeeNumerator);
    }

    /// @inheritdoc IERC1155Pack
    function setPacksContent(bytes32 _merkleRoot, uint256 _supply) external onlyRole(PACK_ADMIN_ROLE) {
        merkleRoot = _merkleRoot;
        supply = _supply;
        remainingSupply = _supply;
    }

    /// @inheritdoc IERC1155Pack
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

    /// @inheritdoc IERC1155Pack
    function reveal(address user, PackContent calldata packContent, bytes32[] calldata proof) external {
        (uint256 randomIndex, uint256 revealIdx) = _getRevealIdx(user);

        bytes32 leaf = keccak256(abi.encode(revealIdx, packContent));
        if (!MerkleProof.verify(proof, merkleRoot, leaf)) {
            revert InvalidProof();
        }

        delete _commitments[user];
        remainingSupply--;

        // Point this index to the last index's value
        _availableIndices[randomIndex] = _getIndexOrDefault(remainingSupply);

        for (uint256 i = 0; i < packContent.tokenAddresses.length; i++) {
            IERC1155ItemsFunctions(packContent.tokenAddresses[i]).batchMint(
                user, packContent.tokenIds[i], packContent.amounts[i], ""
            );
        }

        emit Reveal(user, packContent);
    }

    /// @inheritdoc IERC1155Pack
    function refundPack(address user) external {
        if (_commitments[user] == 0) {
            revert NoCommit();
        }
        if (uint256(blockhash(_commitments[user])) != 0 || block.number <= _commitments[user]) {
            revert PendingReveal();
        }
        delete _commitments[user];
        _mint(user, 1, 1, "");
    }

    /// @inheritdoc IERC1155Pack
    function getRevealIdx(address user) public view returns (uint256 revealIdx) {
        (, revealIdx) = _getRevealIdx(user);
        return revealIdx;
    }

    function _getRevealIdx(address user) internal view returns (uint256 randomIdx, uint256 revealIdx) {
        if (remainingSupply == 0) {
            revert AllPacksOpened();
        }

        bytes32 blockHash = blockhash(_commitments[user]);
        if (uint256(blockHash) == 0) {
            revert InvalidCommit();
        }

        if (_commitments[user] == 0) {
            revert NoCommit();
        }

        randomIdx = uint256(keccak256(abi.encode(blockHash, user))) % remainingSupply;
        revealIdx = _getIndexOrDefault(randomIdx);
        return (randomIdx, revealIdx);
    }

    function _getIndexOrDefault(uint256 index) internal view returns (uint256) {
        uint256 value = _availableIndices[index];
        return value == 0 ? index : value;
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return type(IERC1155Pack).interfaceId == interfaceId || super.supportsInterface(interfaceId);
    }
}
