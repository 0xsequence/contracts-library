// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {IERC721Sale} from "@0xsequence/contracts-library/tokens/ERC721/presets/sale/IERC721Sale.sol";
import {ERC721Token} from "@0xsequence/contracts-library/tokens/ERC721/ERC721Token.sol";
import {
    WithdrawControlled,
    AccessControl,
    SafeERC20,
    IERC20
} from "@0xsequence/contracts-library/tokens/common/WithdrawControlled.sol";
import {MerkleProofSingleUse} from "@0xsequence/contracts-library/tokens/common/MerkleProofSingleUse.sol";

/**
 * An ERC-721 token contract with primary sale mechanisms.
 */
contract ERC721Sale is IERC721Sale, ERC721Token, WithdrawControlled, MerkleProofSingleUse {
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
     * @param tokenContractURI Contract URI of the token
     * @param royaltyReceiver Address of who should be sent the royalty payment
     * @param royaltyFeeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @dev This should be called immediately after deployment.
     */
    function initialize(
        address owner,
        string memory tokenName,
        string memory tokenSymbol,
        string memory tokenBaseURI,
        string memory tokenContractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    )
        public
        virtual
    {
        if (_initialized) {
            revert InvalidInitialization();
        }

        ERC721Token._initialize(owner, tokenName, tokenSymbol, tokenBaseURI, tokenContractURI);
        _setDefaultRoyalty(royaltyReceiver, royaltyFeeNumerator);

        _setupRole(MINT_ADMIN_ROLE, owner);
        _setupRole(WITHDRAW_ROLE, owner);

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
     * Checks the sale is active and takes payment.
     * @param _amount Amount of tokens to mint.
     * @param _proof Merkle proof for allowlist minting.
     */
    function _payForActiveMint(uint256 _amount, bytes32[] calldata _proof) private {
        // Active sale test
        if (_blockTimeOutOfBounds(_saleDetails.startTime, _saleDetails.endTime)) {
            revert SaleInactive();
        }
        requireMerkleProof(_saleDetails.merkleRoot, _proof, msg.sender);

        uint256 total = _saleDetails.cost * _amount;
        address paymentToken = _saleDetails.paymentToken;
        if (paymentToken == address(0)) {
            // Paid in ETH
            if (msg.value != total) {
                revert InsufficientPayment(total, msg.value);
            }
        } else {
            // Paid in ERC20
            SafeERC20.safeTransferFrom(IERC20(paymentToken), msg.sender, address(this), total);
        }
    }

    //
    // Minting
    //

    /**
     * Mint tokens.
     * @param to Address to mint tokens to.
     * @param amount Amount of tokens to mint.
     * @param proof Merkle proof for allowlist minting.
     * @notice Sale must be active for all tokens.
     * @dev An empty proof is supplied when no proof is required.
     */
    function mint(address to, uint256 amount, bytes32[] calldata proof) public payable {
        uint256 currentSupply = totalSupply();
        uint256 supplyCap = _saleDetails.supplyCap;
        if (supplyCap > 0 && currentSupply + amount > supplyCap) {
            revert InsufficientSupply(currentSupply, amount, supplyCap);
        }
        _payForActiveMint(amount, proof);
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
     * @param merkleRoot The merkle root for allowlist minting.
     * @dev A zero end time indicates an inactive sale.
     */
    function setSaleDetails(
        uint256 supplyCap,
        uint256 cost,
        address paymentToken,
        uint64 startTime,
        uint64 endTime,
        bytes32 merkleRoot
    )
        public
        onlyRole(MINT_ADMIN_ROLE)
    {
        _saleDetails = SaleDetails(supplyCap, cost, paymentToken, startTime, endTime, merkleRoot);
        emit SaleDetailsUpdated(supplyCap, cost, paymentToken, startTime, endTime, merkleRoot);
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

    /**
     * Check interface support.
     * @param interfaceId Interface id
     * @return True if supported
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override (ERC721Token, AccessControl)
        returns (bool)
    {
        return interfaceId == type(IERC721Sale).interfaceId || super.supportsInterface(interfaceId);
    }
}
