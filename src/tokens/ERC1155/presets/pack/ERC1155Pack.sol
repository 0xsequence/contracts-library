// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IERC721ItemsFunctions } from "../../../ERC721/presets/items/IERC721Items.sol";
import { ERC1155Items } from "../items/ERC1155Items.sol";
import { IERC1155ItemsFunctions } from "../items/IERC1155Items.sol";
import { IERC1155Pack } from "./IERC1155Pack.sol";

import { MerkleProofLib } from "solady/utils/MerkleProofLib.sol";

contract ERC1155Pack is ERC1155Items, IERC1155Pack {

    bytes32 internal constant PACK_ADMIN_ROLE = keccak256("PACK_ADMIN_ROLE");

    address public immutable erc1155Holder;

    mapping(uint256 => bytes32) public merkleRoot;
    mapping(uint256 => uint256) public supply;
    mapping(uint256 => uint256) public remainingSupply;

    mapping(address => mapping(uint256 => uint256)) internal _commitments;
    mapping(uint256 => mapping(uint256 => uint256)) internal _availableIndices;

    constructor(
        address _erc1155Holder
    ) {
        erc1155Holder = _erc1155Holder;
    }

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
        if (_commitments[msg.sender][packId] != 0) {
            revert PendingReveal();
        }
        _burn(msg.sender, packId, 1);
        _commitments[msg.sender][packId] = block.number + 1;

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

        delete _commitments[user][packId];
        remainingSupply[packId]--;

        // Point this index to the last index's value
        _availableIndices[packId][randomIndex] = _getIndexOrDefault(remainingSupply[packId], packId);

        for (uint256 i; i < packContent.tokenAddresses.length;) {
            address tokenAddr = packContent.tokenAddresses[i];
            uint256[] memory tokenIds = packContent.tokenIds[i];
            if (packContent.isERC721[i]) {
                for (uint256 j; j < tokenIds.length;) {
                    IERC721ItemsFunctions(tokenAddr).mint(user, tokenIds[j]);
                    unchecked {
                        ++j;
                    }
                }
            } else {
                // Send via the holder fallback if available
                address to = user;
                if (erc1155Holder != address(0) && msg.sender != user) {
                    to = erc1155Holder;
                }
                bytes memory packedData = abi.encode(user);
                IERC1155ItemsFunctions(tokenAddr).batchMint(to, tokenIds, packContent.amounts[i], packedData);
            }
            unchecked {
                ++i;
            }
        }

        emit Reveal(user, packId);
    }

    /// @inheritdoc IERC1155Pack
    function refundPack(address user, uint256 packId) external {
        uint256 commitment = _commitments[user][packId];
        if (commitment == 0) {
            revert NoCommit();
        }
        if (uint256(blockhash(commitment)) != 0 || block.number <= commitment) {
            revert PendingReveal();
        }
        delete _commitments[user][packId];
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

        uint256 commitment = _commitments[user][packId];
        if (commitment == 0) {
            revert NoCommit();
        }
        bytes32 blockHash = blockhash(commitment);
        if (uint256(blockHash) == 0) {
            revert InvalidCommit();
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
        return interfaceId == type(IERC1155Pack).interfaceId || super.supportsInterface(interfaceId);
    }

}
