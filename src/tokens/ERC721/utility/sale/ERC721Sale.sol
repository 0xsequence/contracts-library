// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { MerkleProofSingleUse } from "../../../common/MerkleProofSingleUse.sol";
import { SignalsImplicitModeControlled } from "../../../common/SignalsImplicitModeControlled.sol";
import { IERC20, SafeERC20, WithdrawControlled } from "../../../common/WithdrawControlled.sol";
import { IERC721ItemsFunctions } from "../../presets/items/IERC721Items.sol";
import { IERC721Sale, IERC721SaleFunctions } from "./IERC721Sale.sol";

/**
 * An ERC-721 token contract with primary sale mechanisms.
 */
contract ERC721Sale is IERC721Sale, WithdrawControlled, MerkleProofSingleUse, SignalsImplicitModeControlled {

    bytes32 internal constant MINT_ADMIN_ROLE = keccak256("MINT_ADMIN_ROLE");

    bool private _initialized;
    address private _items;
    SaleDetails private _saleDetails;

    /**
     * Initialize the contract.
     * @param owner The owner of the contract
     * @param items The ERC-721 Items contract address
     * @param implicitModeValidator Implicit session validator address
     * @param implicitModeProjectId Implicit session project id
     * @dev This should be called immediately after deployment.
     */
    function initialize(
        address owner,
        address items,
        address implicitModeValidator,
        bytes32 implicitModeProjectId
    ) public virtual {
        if (_initialized) {
            revert InvalidInitialization();
        }

        _items = items;

        _grantRole(DEFAULT_ADMIN_ROLE, owner);
        _grantRole(MINT_ADMIN_ROLE, owner);
        _grantRole(WITHDRAW_ROLE, owner);

        _initializeImplicitMode(owner, implicitModeValidator, implicitModeProjectId);

        _initialized = true;
    }

    /**
     * Checks if the current block.timestamp is out of the give timestamp range.
     * @param _startTime Earliest acceptable timestamp (inclusive).
     * @param _endTime Latest acceptable timestamp (exclusive).
     * @dev A zero endTime value is always considered out of bounds.
     */
    function _blockTimeOutOfBounds(uint256 _startTime, uint256 _endTime) private view returns (bool) {
        // 0 end time indicates inactive sale.
        return _endTime == 0 || block.timestamp < _startTime || block.timestamp >= _endTime; // solhint-disable-line not-rely-on-time
    }

    /**
     * Checks the sale is active, valid and takes payment.
     * @param _amount Amount of tokens to mint.
     * @param _expectedPaymentToken ERC20 token address to accept payment in. address(0) indicates ETH.
     * @param _maxTotal Maximum amount of payment tokens.
     * @param _proof Merkle proof for allowlist minting.
     */
    function _validateMint(
        uint256 _amount,
        address _expectedPaymentToken,
        uint256 _maxTotal,
        bytes32[] calldata _proof
    ) private {
        // Active sale test
        if (_blockTimeOutOfBounds(_saleDetails.startTime, _saleDetails.endTime)) {
            revert SaleInactive();
        }
        // Supply test
        if (_saleDetails.remainingSupply < _amount) {
            revert InsufficientSupply(_saleDetails.remainingSupply, _amount);
        }
        _saleDetails.remainingSupply -= _amount;
        // Check proof
        requireMerkleProof(_saleDetails.merkleRoot, _proof, msg.sender, "");

        uint256 total = _saleDetails.cost * _amount;
        if (_expectedPaymentToken != _saleDetails.paymentToken) {
            // Caller expected different payment token
            revert InsufficientPayment(_saleDetails.paymentToken, total, 0);
        }
        if (_maxTotal < total) {
            // Caller expected to pay less
            revert InsufficientPayment(_expectedPaymentToken, total, _maxTotal);
        }
        if (_expectedPaymentToken == address(0)) {
            // Paid in ETH
            if (msg.value != total) {
                // We expect exact value match
                revert InsufficientPayment(_expectedPaymentToken, total, msg.value);
            }
        } else if (msg.value > 0) {
            // Paid in ERC20, but sent ETH
            revert InsufficientPayment(address(0), 0, msg.value);
        } else {
            // Paid in ERC20
            SafeERC20.safeTransferFrom(IERC20(_expectedPaymentToken), msg.sender, address(this), total);
        }
    }

    //
    // Minting
    //

    /**
     * Mint tokens.
     * @param to Address to mint tokens to.
     * @param amount Amount of tokens to mint.
     * @param paymentToken ERC20 token address to accept payment in. address(0) indicates ETH.
     * @param maxTotal Maximum amount of payment tokens.
     * @param proof Merkle proof for allowlist minting.
     * @notice Sale must be active for all tokens.
     * @dev An empty proof is supplied when no proof is required.
     * @dev `paymentToken` must match the `paymentToken` in the sale details.
     */
    function mint(
        address to,
        uint256 amount,
        address paymentToken,
        uint256 maxTotal,
        bytes32[] calldata proof
    ) public payable {
        _validateMint(amount, paymentToken, maxTotal, proof);
        try IERC721ItemsFunctions(_items).mintSequential(to, amount) { }
        catch {
            // On failure, support old minting method.
            IERC721ItemsFunctions(_items).mint(to, amount);
        }
        emit ItemsMinted(to, amount);
    }

    /**
     * Set the sale details.
     * @param remainingSupply The remaining number of tokens that can be minted by the items contract. 0 indicates unlimited supply.
     * @param cost The amount of payment tokens to accept for each token minted.
     * @param paymentToken The ERC20 token address to accept payment in. address(0) indicates ETH.
     * @param startTime The start time of the sale. Tokens cannot be minted before this time.
     * @param endTime The end time of the sale. Tokens cannot be minted after this time.
     * @param merkleRoot The merkle root for allowlist minting.
     * @dev A zero end time indicates an inactive sale.
     */
    function setSaleDetails(
        uint256 remainingSupply,
        uint256 cost,
        address paymentToken,
        uint64 startTime,
        uint64 endTime,
        bytes32 merkleRoot
    ) public onlyRole(MINT_ADMIN_ROLE) {
        // solhint-disable-next-line not-rely-on-time
        if (endTime < startTime || endTime <= block.timestamp) {
            revert InvalidSaleDetails();
        }
        if (remainingSupply == 0) {
            revert InvalidSaleDetails();
        }
        _saleDetails = SaleDetails(remainingSupply, cost, paymentToken, startTime, endTime, merkleRoot);
        emit SaleDetailsUpdated(remainingSupply, cost, paymentToken, startTime, endTime, merkleRoot);
    }

    //
    // Views
    //
    function itemsContract() external view returns (address) {
        return address(_items);
    }

    /**
     * Get sale details.
     * @return Sale details.
     */
    function saleDetails() external view returns (SaleDetails memory) {
        return _saleDetails;
    }

    /**
     * Check interface support.
     * @param interfaceId Interface id
     * @return True if supported
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(WithdrawControlled, SignalsImplicitModeControlled) returns (bool) {
        return interfaceId == type(IERC721SaleFunctions).interfaceId
            || WithdrawControlled.supportsInterface(interfaceId)
            || SignalsImplicitModeControlled.supportsInterface(interfaceId);
    }

}
