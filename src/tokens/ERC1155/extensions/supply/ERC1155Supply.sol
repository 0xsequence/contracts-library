// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {ERC1155Token} from "@0xsequence/contracts-library/tokens/ERC1155/ERC1155Token.sol";
import {IERC1155Supply} from "@0xsequence/contracts-library/tokens/ERC1155/extensions/supply/IERC1155Supply.sol";

/**
 * An ERC-1155 extension that tracks token supply.
 */
abstract contract ERC1155Supply is ERC1155Token, IERC1155Supply {
    // Maximum supply globaly and per token. 0 indicates unlimited supply
    uint256 internal totalSupplyCap;
    mapping(uint256 => uint256) internal tokenSupplyCap;

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
        // Check supply cap
        if (totalSupplyCap > 0 && totalSupply + _amount > totalSupplyCap) {
            revert InsufficientSupply(totalSupply, _amount, totalSupplyCap);
        }
        totalSupply += _amount;
        if (tokenSupplyCap[_id] > 0 && tokenSupply[_id] + _amount > tokenSupplyCap[_id]) {
            revert InsufficientSupply(tokenSupply[_id], _amount, tokenSupplyCap[_id]);
        }
        tokenSupply[_id] += _amount;

        _mint(_to, _id, _amount, _data);
    }

    /**
     * Mint tokens for each ids in _ids
     * @param _to The address to mint tokens to
     * @param _ids Array of ids to mint
     * @param _amounts Array of amount of tokens to mint per id
     * @param _data Data to pass if receiver is contract
     */
    function _batchMint(address _to, uint256[] memory _ids, uint256[] memory _amounts, bytes memory _data) internal virtual override {
        uint256 nMint = _ids.length;
        if (nMint != _amounts.length) {
            revert InvalidArrayLength();
        }

        // Executing all minting
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < nMint; i++) {
            // Update storage balance
            if (tokenSupplyCap[_ids[i]] > 0 && tokenSupply[_ids[i]] + _amounts[i] > tokenSupplyCap[_ids[i]]) {
                revert InsufficientSupply(tokenSupply[_ids[i]], _amounts[i], tokenSupplyCap[_ids[i]]);
            }
            balances[_to][_ids[i]] += _amounts[i];
            tokenSupply[_ids[i]] += _amounts[i];
            totalAmount += _amounts[i];
        }
        if (totalSupplyCap > 0 && totalSupply + totalAmount > totalSupplyCap) {
            revert InsufficientSupply(totalSupply, totalAmount, totalSupplyCap);
        }
        totalSupply += totalAmount;

        // Emit batch mint event
        emit TransferBatch(msg.sender, address(0x0), _to, _ids, _amounts);

        // Calling onReceive method if recipient is contract
        _callonERC1155BatchReceived(address(0x0), _to, _ids, _amounts, gasleft(), _data);
    }

    /**
     * Burn _amount of tokens of a given token id
     * @param _from The address to burn tokens from
     * @param _id Token id to burn
     * @param _amount The amount to be burned
     */
    function _burn(address _from, uint256 _id, uint256 _amount) internal virtual override {
        // Supply
        totalSupply -= _amount;
        tokenSupply[_id] -= _amount;

        // Balances
        balances[_from][_id] -= _amount;

        // Emit event
        emit TransferSingle(msg.sender, _from, address(0x0), _id, _amount);
    }

    /**
     * Burn tokens of given token id for each (_ids[i], _amounts[i]) pair
     * @param _from The address to burn tokens from
     * @param _ids Array of token ids to burn
     * @param _amounts Array of the amount to be burned
     */
    function _batchBurn(address _from, uint256[] memory _ids, uint256[] memory _amounts) internal virtual override {
        // Number of mints to execute
        uint256 nBurn = _ids.length;
        if (nBurn != _amounts.length) {
            revert InvalidArrayLength();
        }

        // Executing all minting
        for (uint256 i = 0; i < nBurn; i++) {
            // Update balances
            balances[_from][_ids[i]] -= _amounts[i];
            totalSupply -= _amounts[i];
            tokenSupply[_ids[i]] -= _amounts[i];
        }

        // Emit batch mint event
        emit TransferBatch(msg.sender, _from, address(0x0), _ids, _amounts);
    }
}
