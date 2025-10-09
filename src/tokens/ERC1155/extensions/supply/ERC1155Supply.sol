// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IERC1155Supply, IERC1155SupplyFunctions } from "./IERC1155Supply.sol";

import { ERC1155 } from "solady/tokens/ERC1155.sol";

/**
 * An ERC-1155 extension that tracks token supply.
 */
abstract contract ERC1155Supply is ERC1155, IERC1155Supply {

    // Current supply
    uint256 public totalSupply;
    mapping(uint256 => uint256) public tokenSupply;

    /**
     * Mint _amount of tokens of a given id
     * @param _to The address to mint tokens to
     * @param _id Token id to mint
     * @param _amount The amount to be minted
     * @param _data Data to pass if receiver is contract
     */
    function _mint(address _to, uint256 _id, uint256 _amount, bytes memory _data) internal virtual override {
        super._mint(_to, _id, _amount, _data);

        totalSupply += _amount;
        tokenSupply[_id] += _amount;
    }

    /**
     * Mint tokens for each ids in _ids
     * @param _to The address to mint tokens to
     * @param _ids Array of ids to mint
     * @param _amounts Array of amount of tokens to mint per id
     * @param _data Data to pass if receiver is contract
     */
    function _batchMint(
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes memory _data
    ) internal virtual override {
        super._batchMint(_to, _ids, _amounts, _data);

        uint256 nMint = _ids.length;
        uint256 totalAmount = 0;
        for (uint256 i; i < nMint;) {
            uint256 amount = _amounts[i];
            totalAmount += amount;
            tokenSupply[_ids[i]] += amount;
            unchecked {
                // Already checked in super._batchMint
                ++i;
            }
        }
        totalSupply += totalAmount;
    }

    /**
     * Burn _amount of tokens of a given token id
     * @param _from The address to burn tokens from
     * @param _id Token id to burn
     * @param _amount The amount to be burned
     */
    function _burn(address _from, uint256 _id, uint256 _amount) internal virtual override {
        super._burn(_from, _id, _amount);

        totalSupply -= _amount;
        tokenSupply[_id] -= _amount;
    }

    /**
     * Burn tokens of given token id for each (_ids[i], _amounts[i]) pair
     * @param _from The address to burn tokens from
     * @param _ids Array of token ids to burn
     * @param _amounts Array of the amount to be burned
     */
    function _batchBurn(address _from, uint256[] memory _ids, uint256[] memory _amounts) internal virtual override {
        super._batchBurn(_from, _ids, _amounts);

        uint256 nBurn = _ids.length;
        uint256 totalAmount = 0;
        for (uint256 i; i < nBurn;) {
            uint256 amount = _amounts[i];
            tokenSupply[_ids[i]] -= amount;
            totalAmount += amount;
            unchecked {
                // Already checked in super._batchBurn
                ++i;
            }
        }
        totalSupply -= totalAmount;
    }

    //
    // Views
    //

    /**
     * Check interface support.
     * @param interfaceId Interface id
     * @return True if supported
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155) returns (bool) {
        return type(IERC1155SupplyFunctions).interfaceId == interfaceId || super.supportsInterface(interfaceId);
    }

}
