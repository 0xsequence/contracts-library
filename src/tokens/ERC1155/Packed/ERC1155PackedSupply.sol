// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {ERC1155MetaPackedBalance} from
    "@0xsequence/erc-1155/contracts/tokens/ERC1155PackedBalance/ERC1155MetaPackedBalance.sol";
import {ERC1155SupplyErrors} from "../ERC1155SupplyErrors.sol";

/**
 * An ERC1155 extension that tracks token supply.
 */
contract ERC1155PackedSupply is ERC1155MetaPackedBalance, ERC1155SupplyErrors {
    // Maximum supply globally and per token. 0 indicates unlimited supply
    uint256 public totalSupplyCap;
    mapping(uint256 => uint256) public tokenSupplyCap;

    uint256 public totalSupply;
    mapping(uint256 => uint256) public tokenSupply;

    /**
     * Mint _amount of tokens of a given id
     * @param _to The address to mint tokens to
     * @param _id Token id to mint
     * @param _amount The amount to be minted
     * @param _data Data to pass if receiver is contract
     */
    function _mint(address _to, uint256 _id, uint256 _amount, bytes memory _data) internal {
        // Check supply cap
        totalSupply += _amount;
        if (totalSupplyCap > 0 && totalSupply > totalSupplyCap) {
            revert InsufficientSupply();
        }
        tokenSupply[_id] += _amount;
        if (tokenSupplyCap[_id] > 0 && tokenSupply[_id] > tokenSupplyCap[_id]) {
            revert InsufficientSupply();
        }

        //Add _amount
        _updateIDBalance(_to, _id, _amount, Operations.Add); // Add amount to recipient

        // Emit event
        emit TransferSingle(msg.sender, address(0x0), _to, _id, _amount);

        // Calling onReceive method if recipient is contract
        _callonERC1155Received(address(0x0), _to, _id, _amount, gasleft(), _data);
    }

    /**
     * Mint tokens for each ids in _ids
     * @param _to The address to mint tokens to
     * @param _ids Array of ids to mint
     * @param _amounts Array of amount of tokens to mint per id
     * @param _data Data to pass if receiver is contract
     */
    function _batchMint(address _to, uint256[] memory _ids, uint256[] memory _amounts, bytes memory _data) internal {
        uint256 nMint = _ids.length;
        if (nMint == 0 || nMint != _amounts.length) {
            revert InvalidArrayLength();
        }

        // Update supply balance
        uint256 id0 = _ids[0];
        uint256 amount0 = _amounts[0];
        totalSupply += amount0;
        tokenSupply[id0] += amount0;
        if (tokenSupplyCap[id0] > 0 && tokenSupply[id0] > tokenSupplyCap[id0]) {
            revert InsufficientSupply();
        }
        // Load first bin and index where the token ID balance exists
        (uint256 bin, uint256 index) = getIDBinIndex(id0);

        // Balance for current bin in memory (initialized with first transfer)
        uint256 balTo = _viewUpdateBinValue(balances[_to][bin], index, amount0, Operations.Add);

        // Last bin updated
        uint256 lastBin = bin;

        for (uint256 i = 1; i < nMint; i++) {
            // Update supply balance
            totalSupply += _amounts[i];
            tokenSupply[_ids[i]] += _amounts[i];
            if (tokenSupplyCap[_ids[i]] > 0 && tokenSupply[_ids[i]] > tokenSupplyCap[_ids[i]]) {
                revert InsufficientSupply();
            }

            (bin, index) = getIDBinIndex(_ids[i]);

            // If new bin
            if (bin != lastBin) {
                // Update storage balance of previous bin
                balances[_to][lastBin] = balTo;
                balTo = balances[_to][bin];

                // Bin will be the most recent bin
                lastBin = bin;
            }

            // Update memory balance
            balTo = _viewUpdateBinValue(balTo, index, _amounts[i], Operations.Add);
        }

        // Validate total supply cap
        if (totalSupplyCap > 0 && totalSupply > totalSupplyCap) {
            revert InsufficientSupply();
        }

        // Update storage of the last bin visited
        balances[_to][bin] = balTo;

        // //Emit event
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
    function _burn(address _from, uint256 _id, uint256 _amount) internal {
        // Supply
        totalSupply -= _amount;
        tokenSupply[_id] -= _amount;

        // Substract _amount
        _updateIDBalance(_from, _id, _amount, Operations.Sub);

        // Emit event
        emit TransferSingle(msg.sender, _from, address(0x0), _id, _amount);
    }

    /**
     * Burn tokens of given token id for each (_ids[i], _amounts[i]) pair
     * @param _from The address to burn tokens from
     * @param _ids Array of token ids to burn
     * @param _amounts Array of the amount to be burned
     */
    function _batchBurn(address _from, uint256[] memory _ids, uint256[] memory _amounts) internal {
        // Number of mints to execute
        uint256 nBurn = _ids.length;
        if (nBurn == 0 || nBurn != _amounts.length) {
            revert InvalidArrayLength();
        }

        // Executing all minting
        for (uint256 i = 0; i < nBurn; i++) {
            // Update supplies
            totalSupply -= _amounts[i];
            tokenSupply[_ids[i]] -= _amounts[i];

            // Update storage balance
            _updateIDBalance(_from, _ids[i], _amounts[i], Operations.Sub); // Add amount to recipient
        }

        // Emit batch burn event
        emit TransferBatch(msg.sender, _from, address(0x0), _ids, _amounts);
    }
}
