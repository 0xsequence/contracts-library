// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {
    ERC721AQueryable, IERC721AQueryable, ERC721A, IERC721A
} from "erc721a/contracts/extensions/ERC721AQueryable.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SaleErrors} from "../../utils/SaleErrors.sol";

contract ERC721Sale is SaleErrors, ERC721AQueryable, ERC2981, AccessControl {
    bytes32 public constant MINT_ADMIN_ROLE = keccak256("MINT_ADMIN_ROLE");
    bytes32 public constant ROYALTY_ADMIN_ROLE = keccak256("ROYALTY_ADMIN_ROLE");

    bytes4 private constant ERC20_TRANSFERFROM_SELECTOR =
        bytes4(keccak256(bytes("transferFrom(address,address,uint256)")));

    string private baseURI;

    event SaleDetailsUpdated(uint256 amount, address paymentToken, uint64 startTime, uint64 endTime);

    struct SaleDetails {
        uint256 amount;
        address paymentToken; // ERC20 token address for payment. address(0) indicated payment in ETH.
        uint64 startTime;
        uint64 endTime; // 0 end time indicates sale inactive
    }

    SaleDetails public saleDetails;

    constructor(address owner, string memory _name, string memory _symbol, string memory baseURI_)
        ERC721A(_name, _symbol)
    {
        baseURI = baseURI_;
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
     * @param _amount Amount of tokens to mint.
     */
    function payForActiveMint(uint256 _amount) private {
        // Active sale test
        if (blockTimeOutOfBounds(saleDetails.startTime, saleDetails.endTime)) {
            revert GlobalSaleInactive();
        }

        uint256 total = saleDetails.amount * _amount;
        address paymentToken = saleDetails.paymentToken;
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
     * @param _amount Amount of tokens to mint.
     * @notice Sale must be active for all tokens.
     */
    function mint(address _to, uint256 _amount) public payable {
        payForActiveMint(_amount);
        _mint(_to, _amount);
    }

    /**
     * Mint tokens as admin.
     * @param _to Address to mint tokens to.
     * @param _amount Amount of tokens to mint.
     * @notice Only callable by mint admin.
     */
    function mintAdmin(address _to, uint256 _amount) public onlyRole(MINT_ADMIN_ROLE) {
        _mint(_to, _amount);
    }

    /**
     * Set the sale details.
     * @param _paymentToken The ERC20 token address to accept payment in. address(0) indicates ETH.
     * @param _amount The amount of payment tokens to accept for each token minted.
     * @param _startTime The start time of the sale. Tokens cannot be minted before this time.
     * @param _endTime The end time of the sale. Tokens cannot be minted after this time.
     * @dev A zero end time indicates an inactive sale.
     */
    function setSalesDetails(address _paymentToken, uint256 _amount, uint64 _startTime, uint64 _endTime)
        public
        onlyRole(MINT_ADMIN_ROLE)
    {
        saleDetails = SaleDetails(_amount, _paymentToken, _startTime, _endTime);
        emit SaleDetailsUpdated(_amount, _paymentToken, _startTime, _endTime);
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

    //
    // Withdraw
    //

    /**
     * Withdraws ETH or ERC20 tokens owned by this sale contract.
     * @param _to Address to withdraw to.
     * @param _amount Amount to withdraw.
     * @dev Withdraws ERC20 when paymentToken is set, else ETH.
     * @notice Only callable by the contract admin.
     */
    function withdraw(address _to, uint256 _amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        address paymentToken = saleDetails.paymentToken;
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
        override (ERC721A, IERC721A, ERC2981, AccessControl)
        returns (bool)
    {
        return _interfaceId == type(IERC721A).interfaceId || _interfaceId == type(IERC721AQueryable).interfaceId
            || ERC721A.supportsInterface(_interfaceId) || super.supportsInterface(_interfaceId);
    }

    /**
     * Override the ERC721A baseURI function.
     */
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }
}
