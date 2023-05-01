// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {ERC1155, ERC1155Meta} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155Meta.sol";
import {ERC1155Metadata} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155Metadata.sol";
import {ERC1155MintBurn} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155MintBurn.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1155SaleErrors} from "./ERC1155SaleErrors.sol";

contract ERC1155Sale is ERC1155SaleErrors, ERC1155MintBurn, ERC1155Meta, ERC1155Metadata, ERC2981, AccessControl {
    bytes32 public constant MINT_ADMIN_ROLE = keccak256("MINT_ADMIN_ROLE");
    bytes32 public constant ROYALTY_ADMIN_ROLE = keccak256("ROYALTY_ADMIN_ROLE");

    bytes4 private constant ERC20_TRANSFERFROM_SELECTOR =
        bytes4(keccak256(bytes("transferFrom(address,address,uint256)")));

    event GlobalSaleDetailsUpdated(uint256 amount, uint64 startTime, uint64 endTime);
    event TokenSaleDetailsUpdated(uint256 tokenId, uint256 amount, uint64 startTime, uint64 endTime);

    // ERC20 token address for payment. address(0) indicated payment in ETH.
    address public paymentToken;

    struct SaleDetails {
        uint256 amount;
        uint64 startTime;
        uint64 endTime; // 0 end time indicates sale inactive
    }

    SaleDetails public globalSaleDetails;
    mapping(uint256 => SaleDetails) public tokenSaleDetails;

    constructor(address owner, string memory _name, string memory _baseURI) ERC1155Metadata(_name, _baseURI) {
        _setupRole(DEFAULT_ADMIN_ROLE, owner);
        _setupRole(MINT_ADMIN_ROLE, owner);
        _setupRole(ROYALTY_ADMIN_ROLE, owner);
    }

    /**
     * Checks if the current block.timestamp is out of the give timestamp range.
     * @param startTime Earliest acceptable timestamp (inclusive).
     * @param endTime Latest acceptable timestamp (exclusive).
     * @dev A zero endTime value is always considered out of bounds.
     */
    function blockTimeOutOfBounds(uint256 startTime, uint256 endTime) private view returns (bool) {
        // 0 end time indicates inactive sale.
        return endTime == 0 || block.timestamp < startTime || block.timestamp >= endTime;
    }

    /**
     * Checks the sale is active and takes payment.
     * @param _tokenIds Token IDs to mint.
     * @param _amounts Amounts of tokens to mint.
     */
    function payForActiveMint(uint256[] memory _tokenIds, uint256[] memory _amounts) private {
        uint256 total;
        bool globalSaleInactive = blockTimeOutOfBounds(globalSaleDetails.startTime, globalSaleDetails.endTime);
        for (uint256 i; i < _tokenIds.length; i++) {
            // Active sale test
            SaleDetails memory saleDetails = tokenSaleDetails[_tokenIds[i]];
            bool tokenSaleInactive = blockTimeOutOfBounds(saleDetails.startTime, saleDetails.endTime);
            if (tokenSaleInactive) {
                // Prefer token sale
                if (globalSaleInactive) {
                    // Both sales inactive
                    revert SaleInactive(_tokenIds[i]);
                }
                // Use global sale price
                total += globalSaleDetails.amount * _amounts[i];
            } else {
                // Use token sale price
                total += saleDetails.amount * _amounts[i];
            }
        }

        if (paymentToken == address(0)) {
            // Paid in ETH
            if (msg.value != total) {
                revert InsufficientPayment(total, msg.value);
            }
        } else {
            // Paid in ERC20
            (bool success, bytes memory data) =
                paymentToken.call(abi.encodeWithSelector(ERC20_TRANSFERFROM_SELECTOR, msg.sender, address(this), total));
            if (!success || (data.length > 0 && !abi.decode(data, (bool)))) {
                revert InsufficientPayment(total, 0);
            }
        }
    }

    //
    // Minting
    //

    /**
     * Mint tokens.
     * @param _to Address to mint tokens to.
     * @param _tokenIds Token IDs to mint.
     * @param _amounts Amounts of tokens to mint.
     * @param _data Data to pass if receiver is contract.
     * @notice Sale must be active for all tokens.
     */
    function mint(address _to, uint256[] memory _tokenIds, uint256[] memory _amounts, bytes memory _data)
        public
        payable
    {
        payForActiveMint(_tokenIds, _amounts);
        _batchMint(_to, _tokenIds, _amounts, _data);
    }

    /**
     * Set the global sale details.
     * @param _paymentToken The ERC20 token address to accept payment in. address(0) indicates ETH.
     * @param _amount The amount of payment tokens to accept for each token minted.
     * @param _startTime The start time of the sale. Tokens cannot be minted before this time.
     * @param _endTime The end time of the sale. Tokens cannot be minted after this time.
     * @dev A zero end time indicates an inactive sale.
     */
    function setGlobalSalesDetails(address _paymentToken, uint256 _amount, uint64 _startTime, uint64 _endTime)
        public
        onlyRole(MINT_ADMIN_ROLE)
    {
        paymentToken = _paymentToken;
        globalSaleDetails = SaleDetails(_amount, _startTime, _endTime);
        emit GlobalSaleDetailsUpdated(_amount, _startTime, _endTime);
    }

    /**
     * Set the sale details for an individual token.
     * @param _tokenId The token ID to set the sale details for.
     * @param _amount The amount of payment tokens to accept for each token minted.
     * @param _startTime The start time of the sale. Tokens cannot be minted before this time.
     * @param _endTime The end time of the sale. Tokens cannot be minted after this time.
     * @dev A zero end time indicates an inactive sale.
     */
    function setTokenSalesDetails(uint256 _tokenId, uint256 _amount, uint64 _startTime, uint64 _endTime)
        public
        onlyRole(MINT_ADMIN_ROLE)
    {
        tokenSaleDetails[_tokenId] = SaleDetails(_amount, _startTime, _endTime);
        emit TokenSaleDetailsUpdated(_tokenId, _amount, _startTime, _endTime);
    }

    //
    // Royalty
    //

    /**
     * Sets the royalty information that all ids in this contract will default to.
     * @param _receiver Address of who should be sent the royalty payment
     * @param _feeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     */
    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) public onlyRole(ROYALTY_ADMIN_ROLE) {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    /**
     * Sets the royalty information that a given token id in this contract will use.
     * @param _tokenId The token id to set the royalty information for
     * @param _receiver Address of who should be sent the royalty payment
     * @param _feeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @notice This overrides the default royalty information for this token id
     */
    function setTokenRoyalty(uint256 _tokenId, address _receiver, uint96 _feeNumerator)
        public
        onlyRole(ROYALTY_ADMIN_ROLE)
    {
        _setTokenRoyalty(_tokenId, _receiver, _feeNumerator);
    }

    //
    // Withdraw
    //

    /**
     * Withdraws ETH or ERC20 tokens owned by this sale contract.
     * @dev Withdraws ERC20 when paymentToken is set, else ETH.
     * @notice Only callable by the contract admin.
     */
    function withdraw(address _to, uint256 _amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (paymentToken == address(0)) {
            (bool success,) = _to.call{value: _amount}("");
            if (!success) {
                revert WithdrawFailed();
            }
        } else {
            (bool success) = IERC20(paymentToken).transfer(_to, _amount);
            if (!success) {
                revert WithdrawFailed();
            }
        }
    }

    //
    // Views
    //
    function supportsInterface(bytes4 _interfaceId)
        public
        view
        override (ERC1155, ERC1155Metadata, ERC2981, AccessControl)
        returns (bool)
    {
        // FIXME Fix inheritance issues
        return ERC1155.supportsInterface(_interfaceId) || ERC1155Metadata.supportsInterface(_interfaceId)
            || super.supportsInterface(_interfaceId);
    }
}
