// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {
    ERC1155PackedBalance,
    ERC1155MintBurnPackedBalance
} from "@0xsequence/erc-1155/contracts/tokens/ERC1155PackedBalance/ERC1155MintBurnPackedBalance.sol";
import {ERC1155MetaPackedBalance} from
    "@0xsequence/erc-1155/contracts/tokens/ERC1155PackedBalance/ERC1155MetaPackedBalance.sol";
import {ERC1155Metadata} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155Metadata.sol";
import {ERC2981Controlled} from "../../common/ERC2981Controlled.sol";

error InvalidInitialization();

/**
 * A ready made implementation of ERC-1155.
 */
contract ERC1155PackedToken is
    ERC1155MintBurnPackedBalance,
    ERC1155MetaPackedBalance,
    ERC1155Metadata,ERC2981Controlled
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant METADATA_ADMIN_ROLE = keccak256("METADATA_ADMIN_ROLE");

    address private immutable _initializer;
    bool private _initialized;

    /**
     * Initialize contract.
     */
    constructor() ERC1155Metadata("", "") {
        _initializer = msg.sender;
    }

    /**
     * Initialize the contract.
     * @param _owner Owner address.
     * @param _name Token name.
     * @param _baseURI Base URI for token metadata.
     * @dev This should be called immediately after deployment.
     */
    function initialize(address _owner, string memory _name, string memory _baseURI) public {
        if (msg.sender != _initializer || _initialized) {
            revert InvalidInitialization();
        }
        _initialized = true;

        name = _name;
        baseURI = _baseURI;

        _setupRole(DEFAULT_ADMIN_ROLE, _owner);
        _setupRole(MINTER_ROLE, _owner);
        _setupRole(ROYALTY_ADMIN_ROLE, _owner);
        _setupRole(METADATA_ADMIN_ROLE, _owner);
    }

    //
    // Minting
    //

    /**
     * Mint tokens.
     * @param _to Address to mint tokens to.
     * @param _tokenId Token ID to mint.
     * @param _amount Amount of tokens to mint.
     * @param _data Data to pass if receiver is contract.
     */
    function mint(address _to, uint256 _tokenId, uint256 _amount, bytes memory _data) external onlyRole(MINTER_ROLE) {
        _mint(_to, _tokenId, _amount, _data);
    }

    /**
     * Mint tokens.
     * @param _to Address to mint tokens to.
     * @param _tokenIds Token IDs to mint.
     * @param _amounts Amounts of tokens to mint.
     * @param _data Data to pass if receiver is contract.
     */
    function batchMint(address _to, uint256[] memory _tokenIds, uint256[] memory _amounts, bytes memory _data)
        external
        onlyRole(MINTER_ROLE)
    {
        _batchMint(_to, _tokenIds, _amounts, _data);
    }

    //
    // Metadata
    //

    /**
     * Update the base URL of token's URI.
     * @param _baseMetadataURI New base URL of token's URI
     */
    function setBaseMetadataURI(string memory _baseMetadataURI) external onlyRole(METADATA_ADMIN_ROLE) {
        _setBaseMetadataURI(_baseMetadataURI);
    }

    /**
     * Update the name of the contract.
     * @param _name New contract name
     */
    function setContractName(string memory _name) external onlyRole(METADATA_ADMIN_ROLE) {
        _setContractName(_name);
    }

    //
    // Views
    //

    /**
     * Check interface support.
     * @param _interfaceId Interface id
     * @return True if supported
     */
    function supportsInterface(bytes4 _interfaceId)
        public
        view
        override (ERC1155PackedBalance, ERC1155Metadata, ERC2981Controlled)
        returns (bool)
    {
        return ERC1155PackedBalance.supportsInterface(_interfaceId) || ERC1155Metadata.supportsInterface(_interfaceId)
            || ERC2981Controlled.supportsInterface(_interfaceId)
            || super.supportsInterface(_interfaceId);
    }
}
