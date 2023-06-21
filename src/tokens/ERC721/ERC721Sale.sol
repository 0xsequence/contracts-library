// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {IERC721Sale} from "./IERC721Sale.sol";
import {ERC721Token} from "./ERC721Token.sol";
import {ERC721SaleErrors} from "./ERC721SaleErrors.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC721Sale is IERC721Sale, ERC721Token, ERC721SaleErrors {
    bytes32 public constant MINT_ADMIN_ROLE = keccak256("MINT_ADMIN_ROLE");

    bytes4 private constant _ERC20_TRANSFERFROM_SELECTOR =
        bytes4(keccak256(bytes("transferFrom(address,address,uint256)")));

    bool private _initialized;

    SaleDetails private _saleDetails;

    /**
     * Initialize the contract.
     * @param owner The owner of the contract
     * @param tokenName Name of the token
     * @param tokenSymbol Symbol of the token
     * @param tokenBaseURI Base URI of the token
     * @dev This should be called immediately after deployment.
     */
    function initialize(address owner, string memory tokenName, string memory tokenSymbol, string memory tokenBaseURI)
        public
        virtual
        override
    {
        if (_initialized) {
            revert InvalidInitialization();
        }

        ERC721Token.initialize(owner, tokenName, tokenSymbol, tokenBaseURI);
        _setupRole(MINT_ADMIN_ROLE, owner);

        _initialized = true;
    }

    /**
     * Checks if the current block.timestamp is out of the give timestamp range.
     * @param _startTime Earliest acceptable timestamp (inclusive).
     * @param _endTime Latest acceptable timestamp (exclusive).
     * @dev A zero endTime value is always considered out of bounds.
     */
    function blockTimeOutOfBounds(uint256 _startTime, uint256 _endTime) private view returns (bool) {
        // 0 end time indicates inactive sale.
        return _endTime == 0 || block.timestamp < _startTime || block.timestamp >= _endTime; // solhint-disable-line not-rely-on-time
    }

    /**
     * Checks the sale is active and takes payment.
     * @param _amount Amount of tokens to mint.
     */
    function _payForActiveMint(uint256 _amount) private {
        // Active sale test
        if (blockTimeOutOfBounds(_saleDetails.startTime, _saleDetails.endTime)) {
            revert SaleInactive();
        }

        uint256 total = _saleDetails.cost * _amount;
        address paymentToken = _saleDetails.paymentToken;
        if (paymentToken == address(0)) {
            // Paid in ETH
            if (msg.value != total) {
                revert InsufficientPayment(total, msg.value);
            }
        } else {
            // Paid in ERC20
            (bool success, bytes memory data) =
                paymentToken.call(abi.encodeWithSelector(_ERC20_TRANSFERFROM_SELECTOR, msg.sender, address(this), total));
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
     * @param to Address to mint tokens to.
     * @param amount Amount of tokens to mint.
     * @notice Sale must be active for all tokens.
     */
    function mint(address to, uint256 amount) public payable {
        uint256 currentSupply = totalSupply();
        uint256 supplyCap = _saleDetails.supplyCap;
        if (supplyCap > 0 && currentSupply + amount > supplyCap) {
            revert InsufficientSupply(currentSupply, amount, supplyCap);
        }
        _payForActiveMint(amount);
        _mint(to, amount);
    }

    /**
     * Mint tokens as admin.
     * @param to Address to mint tokens to.
     * @param amount Amount of tokens to mint.
     * @notice Only callable by mint admin.
     */
    function mintAdmin(address to, uint256 amount) public onlyRole(MINT_ADMIN_ROLE) {
        _mint(to, amount);
    }

    /**
     * Set the sale details.
     * @param supplyCap The maximum number of tokens that can be minted. 0 indicates unlimited supply.
     * @param cost The amount of payment tokens to accept for each token minted.
     * @param paymentToken The ERC20 token address to accept payment in. address(0) indicates ETH.
     * @param startTime The start time of the sale. Tokens cannot be minted before this time.
     * @param endTime The end time of the sale. Tokens cannot be minted after this time.
     * @dev A zero end time indicates an inactive sale.
     */
    function setSaleDetails(
        uint256 supplyCap,
        uint256 cost,
        address paymentToken,
        uint64 startTime,
        uint64 endTime
    )
        public
        onlyRole(MINT_ADMIN_ROLE)
    {
        _saleDetails = SaleDetails(supplyCap, cost, paymentToken, startTime, endTime);
        emit SaleDetailsUpdated(supplyCap, cost, paymentToken, startTime, endTime);
    }

    //
    // Withdraw
    //

    /**
     * Withdraws ETH or ERC20 tokens owned by this sale contract.
     * @param to Address to withdraw to.
     * @param amount Amount to withdraw.
     * @dev Withdraws ERC20 when paymentToken is set, else ETH.
     * @notice Only callable by the contract admin.
     */
    function withdraw(address to, uint256 amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        address paymentToken = _saleDetails.paymentToken;
        if (paymentToken == address(0)) {
            (bool success,) = to.call{value: amount}("");
            if (!success) {
                revert WithdrawFailed();
            }
        } else {
            (bool success) = IERC20(paymentToken).transfer(to, amount);
            if (!success) {
                revert WithdrawFailed();
            }
        }
    }

    //
    // Views
    //

    /**
     * Get sale details.
     * @return Sale details.
     */
    function saleDetails() external view returns (SaleDetails memory) {
        return _saleDetails;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return interfaceId == type(IERC721Sale).interfaceId || super.supportsInterface(interfaceId);
    }
}
