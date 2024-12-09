// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ILootbox} from "./ILootbox.sol";
import {ERC1155Items} from "@0xsequence/contracts-library/tokens/ERC1155/presets/items/ERC1155Items.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IERC1155ItemsFunctions} from "@0xsequence/contracts-library/tokens/ERC1155/presets/items/IERC1155Items.sol";

contract Lootbox is ERC1155Items, ILootbox {
    bytes32 public merkleRoot;
    uint256 public boxSupply;

    mapping(address => uint256) private _commitments;
    mapping(uint256 => address) private _reveals;
    mapping(uint256 => bool) private _claimedIndexes;

    constructor() ERC1155Items() {}

    /**
     * Initialize the contract.
     * @param owner Owner address
     * @param tokenName Token name
     * @param tokenBaseURI Base URI for token metadata
     * @param tokenContractURI Contract URI for token metadata
     * @param royaltyReceiver Address of who should be sent the royalty payment
     * @param royaltyFeeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @param _merkleRoot Merkle root built from box contents
     * @param _boxSupply Total amount of boxes
     * @dev This should be called immediately after deployment.
     */
    function initialize(
        address owner,
        string memory tokenName,
        string memory tokenBaseURI,
        string memory tokenContractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        bytes32 _merkleRoot,
        uint256 _boxSupply
    ) public virtual {
        merkleRoot = _merkleRoot;
        boxSupply = _boxSupply;
        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        super.initialize(
            owner,
            tokenName,
            tokenBaseURI,
            tokenContractURI,
            royaltyReceiver,
            royaltyFeeNumerator
        );
    }

    function commit() external {
        _commitments[msg.sender] = block.number + 1;
        emit Commit(msg.sender);
    }

    function getRevealId(address user) external returns (uint256 revealIdx) {
        revealIdx =
            uint256(
                keccak256(abi.encode(blockhash(_commitments[user]), user))
            ) %
            boxSupply;
        _reveals[revealIdx] = user;
    }

    function reveal(
        uint256 revealIdx,
        BoxContent calldata boxContent,
        bytes32[] calldata proof
    ) public {
        while (_claimedIndexes[revealIdx]) {
            revealIdx++;
            if (revealIdx >= boxSupply) revealIdx = 0;
        }
        address user = _reveals[revealIdx];
        bytes32 leaf = keccak256(abi.encode(revealIdx, boxContent));

        require(MerkleProof.verify(proof, merkleRoot, leaf), "Invalid proof");

        for (uint256 i = 0; i < boxContent.tokenAddresses.length; i++) {
            IERC1155ItemsFunctions(boxContent.tokenAddresses[i]).mint(
                user,
                boxContent.tokenIds[i],
                boxContent.amounts[i],
                ""
            );
        }
    }

    function setMerkleRoot(
        bytes32 _merkleRoot
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        merkleRoot = _merkleRoot;
    }
}
