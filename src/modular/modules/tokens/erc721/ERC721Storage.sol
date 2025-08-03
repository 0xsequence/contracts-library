// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

// solhint-disable no-inline-assembly

/// @title ERC721Storage
/// @author Michael Standen
/// @notice Typed accessors for ERC721 hitchhiked storage layout.
/// @dev This is a copy of the ERC721Storage library from solady with additional metadata and supply storage.
library ERC721Storage {

    /// @notice Metadata for the ERC721
    /// @param name The name of the ERC721
    /// @param symbol The symbol of the ERC721
    /// @param baseURI The base URI for the ERC721
    /// @param contractURI The contract URI for the ERC721
    /// @custom:storage-location erc7201:erc721.metadata
    struct Metadata {
        string name;
        string symbol;
        string baseURI;
        string contractURI;
    }

    /// @notice Supply for the ERC721
    /// @param totalSupply The total supply of the ERC721
    /// @custom:storage-location erc7201:erc721.supply
    struct Supply {
        uint256 totalSupply;
    }

    /// @dev The balance is too high
    error BalanceTooHigh();

    uint256 internal constant _MAX_ACCOUNT_BALANCE = 0xffffffff;
    uint256 internal constant _ERC721_MASTER_SLOT_SEED = 0x7d8825530a5a2e7a << 192;
    uint256 internal constant _ERC721_MASTER_SLOT_SEED_MASKED = 0x0a5a2e7a00000000;
    bytes32 private constant METADATA_STORAGE_SLOT =
        keccak256(abi.encode(uint256(keccak256("erc721.metadata")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant SUPPLY_STORAGE_SLOT =
        keccak256(abi.encode(uint256(keccak256("erc721.supply")) - 1)) & ~bytes32(uint256(0xff));

    /// @notice Get the metadata storage from storage
    /// @return data The stored metadata data
    function loadMetadata() internal pure returns (Metadata storage data) {
        bytes32 slot = METADATA_STORAGE_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            data.slot := slot
        }
    }

    function loadSupply() internal pure returns (Supply storage data) {
        bytes32 slot = SUPPLY_STORAGE_SLOT;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            data.slot := slot
        }
    }

    /// @notice Computes the balance + aux storage slot for a given owner
    /// @param owner The token owner
    /// @return slot The storage slot
    function balanceSlot(
        address owner
    ) private pure returns (bytes32 slot) {
        assembly {
            mstore(0x1c, _ERC721_MASTER_SLOT_SEED)
            mstore(0x00, owner)
            slot := keccak256(0x0c, 0x1c)
        }
    }

    /// @notice Returns the balance of a given owner
    /// @param owner The token owner
    /// @return bal The balance of the owner
    function getBalance(
        address owner
    ) private view returns (uint256 bal) {
        bytes32 slot = balanceSlot(owner);
        assembly {
            bal := shr(32, sload(slot))
        }
    }

    /// @notice Sets the balance of a given owner
    /// @param owner The token owner
    /// @param bal The balance to set
    function setBalance(address owner, uint256 bal) private {
        bytes32 slot = balanceSlot(owner);
        if (bal > _MAX_ACCOUNT_BALANCE) {
            revert BalanceTooHigh();
        }
        assembly {
            let packed := sload(slot)
            sstore(slot, xor(packed, shl(32, xor(bal, shr(32, packed)))))
        }
    }

    /// @notice Computes the operator approval slot for a given owner/operator
    /// @param owner The token owner
    /// @param operator The operator
    /// @return slot The storage slot
    function operatorApprovalSlot(address owner, address operator) private pure returns (bytes32 slot) {
        assembly {
            mstore(0x1c, or(_ERC721_MASTER_SLOT_SEED, operator))
            mstore(0x00, owner)
            slot := keccak256(0x0c, 0x30)
        }
    }

    /// @notice Returns the operator approval for a given owner/operator
    /// @param owner The token owner
    /// @param operator The operator
    /// @return approved The operator approval
    function getOperatorApproval(address owner, address operator) private view returns (bool approved) {
        bytes32 slot = operatorApprovalSlot(owner, operator);
        assembly {
            approved := sload(slot)
        }
    }

    /// @notice Sets the operator approval for a given owner/operator
    /// @param owner The token owner
    /// @param operator The operator
    /// @param approved The operator approval
    function setOperatorApproval(address owner, address operator, bool approved) private {
        bytes32 slot = operatorApprovalSlot(owner, operator);
        assembly {
            sstore(slot, approved)
        }
    }

    /// @notice Computes the ownership slot for a given token ID
    /// @param id The token ID
    /// @return slot The storage slot for ownership data
    function ownershipSlot(
        uint256 id
    ) private pure returns (bytes32 slot) {
        assembly {
            mstore(0x00, id)
            mstore(0x1c, _ERC721_MASTER_SLOT_SEED)
            slot := add(id, add(id, keccak256(0x00, 0x20)))
        }
    }

    /// @notice Returns the owner of a given token ID
    /// @param id The token ID
    /// @return owner The owner of the token
    function getOwner(
        uint256 id
    ) internal view returns (address owner) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, id)
            mstore(0x1c, _ERC721_MASTER_SLOT_SEED)
            owner := shr(96, shl(96, sload(add(id, add(id, keccak256(0x00, 0x20))))))
        }
    }

    /// @notice Sets the owner of a given token ID
    /// @param id The token ID
    /// @param owner The owner to set
    function setOwner(uint256 id, address owner) internal {
        bytes32 slot = ownershipSlot(id);
        assembly {
            let packed := sload(slot)
            sstore(slot, xor(packed, shl(96, xor(owner, shr(96, packed)))))
        }
    }

    /// @notice Computes the approved address slot for a given token ID
    /// @param id The token ID
    /// @return slot The storage slot for approved address
    function approvedSlot(
        uint256 id
    ) private pure returns (bytes32 slot) {
        assembly {
            mstore(0x00, id)
            mstore(0x1c, _ERC721_MASTER_SLOT_SEED)
            slot := add(1, add(id, add(id, keccak256(0x00, 0x20))))
        }
    }

    /// @notice Returns the approved address for a given token ID
    /// @param id The token ID
    /// @return approved The approved address
    function getApproved(
        uint256 id
    ) internal view returns (address approved) {
        bytes32 slot = approvedSlot(id);
        assembly {
            approved := sload(slot)
        }
    }

    /// @notice Sets the approved address for a given token ID
    /// @param id The token ID
    /// @param approved The approved address
    function setApproved(uint256 id, address approved) internal {
        bytes32 slot = approvedSlot(id);
        assembly {
            sstore(slot, approved)
        }
    }

    /// @notice Returns the aux data for an address
    /// @param owner The token owner
    function getAux(
        address owner
    ) internal view returns (uint224 result) {
        bytes32 slot = balanceSlot(owner);
        assembly {
            result := shr(32, sload(slot))
        }
    }

    /// @notice Sets the aux data for an address
    /// @param owner The token owner
    /// @param value The aux data to set
    function setAux(address owner, uint224 value) internal {
        bytes32 slot = balanceSlot(owner);
        assembly {
            let packed := sload(slot)
            sstore(slot, xor(packed, shl(32, xor(value, shr(32, packed)))))
        }
    }

    /// @notice Returns the extra data for a token ID
    /// @param id The token ID
    function getExtraData(
        uint256 id
    ) internal view returns (uint96 result) {
        bytes32 slot = ownershipSlot(id);
        assembly {
            result := shr(160, sload(slot))
        }
    }

    /// @notice Sets the extra data for a token ID
    /// @param id The token ID
    /// @param value The extra data to set
    function setExtraData(uint256 id, uint96 value) internal {
        bytes32 slot = ownershipSlot(id);
        assembly {
            let packed := sload(slot)
            sstore(slot, xor(packed, shl(160, xor(value, shr(160, packed)))))
        }
    }

}
