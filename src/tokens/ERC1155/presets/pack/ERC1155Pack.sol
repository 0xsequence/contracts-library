// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IERC721ItemsFunctions } from "../../../ERC721/presets/items/IERC721Items.sol";
import { ERC1155Items } from "../items/ERC1155Items.sol";
import { IERC1155ItemsFunctions } from "../items/IERC1155Items.sol";
import { IERC1155Pack } from "./IERC1155Pack.sol";

import { MerkleProofLib } from "solady/utils/MerkleProofLib.sol";

contract ERC1155Pack is ERC1155Items, IERC1155Pack {

    bytes32 internal constant PACK_ADMIN_ROLE = keccak256("PACK_ADMIN_ROLE");

    mapping(uint256 => bytes32) public merkleRoot;
    mapping(uint256 => uint256) public supply;
    mapping(uint256 => uint256) public remainingSupply;

    mapping(uint256 => mapping(address => uint256)) internal _commitments;
    mapping(uint256 => mapping(uint256 => uint256)) internal _availableIndices;

    constructor() ERC1155Items() { }

    /// @inheritdoc ERC1155Items
    function initialize(
        address owner,
        string memory tokenName,
        string memory tokenBaseURI,
        string memory tokenContractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        address implicitModeValidator,
        bytes32 implicitModeProjectId
    ) public virtual override {
        _grantRole(PACK_ADMIN_ROLE, owner);
        super.initialize(
            owner,
            tokenName,
            tokenBaseURI,
            tokenContractURI,
            royaltyReceiver,
            royaltyFeeNumerator,
            implicitModeValidator,
            implicitModeProjectId
        );
    }

    /// @inheritdoc IERC1155Pack
    function setPacksContent(bytes32 _merkleRoot, uint256 _supply, uint256 packId) external onlyRole(PACK_ADMIN_ROLE) {
        merkleRoot[packId] = _merkleRoot;
        supply[packId] = _supply;
        remainingSupply[packId] = _supply;
    }

    /// @inheritdoc IERC1155Pack
    function commit(
        uint256 packId
    ) external {
        if (_commitments[packId][msg.sender] != 0) {
            revert PendingReveal();
        }
        _burn(msg.sender, packId, 1);
        uint256 revealAfterBlock = block.number + 1;
        _commitments[packId][msg.sender] = revealAfterBlock;

        emit Commit(msg.sender, packId);
    }

    /// @inheritdoc IERC1155Pack
    function reveal(
        address user,
        PackContent calldata packContent,
        bytes32[] calldata proof,
        uint256 packId
    ) external {
        (uint256 randomIndex, uint256 revealIdx) = _getRevealIdx(user, packId);

        bytes32 leaf = keccak256(abi.encode(revealIdx, packContent));
        if (!MerkleProofLib.verify(proof, merkleRoot[packId], leaf)) {
            revert InvalidProof();
        }

        delete _commitments[packId][user];
        remainingSupply[packId]--;

        // Point this index to the last index's value
        _availableIndices[packId][randomIndex] = _getIndexOrDefault(remainingSupply[packId], packId);

        for (uint256 i = 0; i < packContent.tokenAddresses.length; i++) {
            if (packContent.isERC721[i]) {
                for (uint256 j = 0; j < packContent.tokenIds[i].length; j++) {
                    IERC721ItemsFunctions(packContent.tokenAddresses[i]).mint(user, packContent.tokenIds[i][j]);
                }
            } else {
                IERC1155ItemsFunctions(packContent.tokenAddresses[i]).batchMint(
                    user, packContent.tokenIds[i], packContent.amounts[i], ""
                );
            }
        }

        emit Reveal(user, packId);
    }

    /// @inheritdoc IERC1155Pack
    function refundPack(address user, uint256 packId) external {
        if (_commitments[packId][user] == 0) {
            revert NoCommit();
        }
        if (uint256(blockhash(_commitments[packId][user])) != 0 || block.number <= _commitments[packId][user]) {
            revert PendingReveal();
        }
        delete _commitments[packId][user];
        _mint(user, packId, 1, "");
    }

    /// @inheritdoc IERC1155Pack
    function getRevealIdx(address user, uint256 packId) public view returns (uint256 revealIdx) {
        (, revealIdx) = _getRevealIdx(user, packId);
        return revealIdx;
    }

    function _getRevealIdx(address user, uint256 packId) internal view returns (uint256 randomIdx, uint256 revealIdx) {
        if (remainingSupply[packId] == 0) {
            revert AllPacksOpened();
        }

        bytes32 blockHash = blockhash(_commitments[packId][user]);
        if (uint256(blockHash) == 0) {
            revert InvalidCommit();
        }

        if (_commitments[packId][user] == 0) {
            revert NoCommit();
        }

        randomIdx = uint256(keccak256(abi.encode(blockHash, user))) % remainingSupply[packId];
        revealIdx = _getIndexOrDefault(randomIdx, packId);
        return (randomIdx, revealIdx);
    }

    function _getIndexOrDefault(uint256 index, uint256 packId) internal view returns (uint256) {
        uint256 value = _availableIndices[packId][index];
        return value == 0 ? index : value;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return type(IERC1155Pack).interfaceId == interfaceId || super.supportsInterface(interfaceId);
    }

}
