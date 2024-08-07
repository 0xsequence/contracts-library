// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IPaymentsFunctions {
    enum TokenType {
        ERC20,
        ERC721,
        ERC1155
    }

    struct PaymentRecipient {
        // Payment recipient
        address recipient;
        // Payment amount
        uint256 amount;
    }

    struct ChainedCallDetails {
        // Address for chained call
        address chainedCallAddress;
        // Data for chained call
        bytes chainedCallData;
    }

    struct PaymentDetails {
        // Unique ID for this purchase
        uint256 purchaseId;
        // Recipient of the purchased product
        address productRecipient;
        // Type of payment token
        TokenType tokenType;
        // Token address to use for payment
        address tokenAddress;
        // Token ID to use for payment. Used for ERC-721 and 1155 payments
        uint256 tokenId;
        // Payment receipients
        PaymentRecipient[] paymentRecipients;
        // Expiration time of the payment
        uint64 expiration;
        // ID of the product
        string productId;
        // Chained call details
        ChainedCallDetails chainedCallDetails;
    }

    /**
     * Returns the hash of the payment details.
     * @param paymentDetails The payment details.
     * @return paymentHash The hash of the payment details for signing.
     */
    function hashPaymentDetails(PaymentDetails calldata paymentDetails) external view returns (bytes32 paymentHash);

    /**
     * Check is a payment signature is valid.
     * @param paymentDetails The payment details.
     * @param signature The signature of the payment.
     * @return isValid True if the signature is valid.
     */
    function isValidPaymentSignature(PaymentDetails calldata paymentDetails, bytes calldata signature)
        external
        view
        returns (bool isValid);

    /**
     * Make a payment for a product.
     * @param paymentDetails The payment details.
     * @param signature The signature of the payment.
     */
    function makePayment(PaymentDetails calldata paymentDetails, bytes calldata signature) external payable;

    /**
     * Check if a payment has been accepted.
     * @param purchaseId The ID of the purchase.
     * @return accepted True if the payment has been accepted.
     */
    function paymentAccepted(uint256 purchaseId) external view returns (bool);

    /**
     * Returns the hash of the chained call.
     * @param chainedCallDetails The chained call details.
     * @return callHash The hash of the chained call for signing.
     */
    function hashChainedCallDetails(ChainedCallDetails calldata chainedCallDetails)
        external
        view
        returns (bytes32 callHash);

    /**
     * Complete a chained call.
     * @param chainedCallDetails The chained call details.
     * @param signature The signature of the chained call.
     * @dev This is called when a payment is accepted off/cross chain.
     */
    function performChainedCall(ChainedCallDetails calldata chainedCallDetails, bytes calldata signature) external;

    /**
     * Check is a chained call signature is valid.
     * @param chainedCallDetails The chained call details.
     * @param signature The signature of the chained call.
     * @return isValid True if the signature is valid.
     */
    function isValidChainedCallSignature(ChainedCallDetails calldata chainedCallDetails, bytes calldata signature)
        external
        view
        returns (bool isValid);

    /**
     * Get the signer address.
     * @return signer The signer address.
     */
    function signer() external view returns (address);
}

interface IPaymentsSignals {
    /// @notice Emitted when contract is already initialized.
    error InvalidInitialization();

    /// @notice Emitted when a payment is already accepted. This prevents double spending.
    error PaymentAlreadyAccepted();

    /// @notice Emitted when a signature is invalid.
    error InvalidSignature();

    /// @notice Emitted when a payment has expired.
    error PaymentExpired();

    /// @notice Emitted when a token transfer is invalid.
    error InvalidTokenTransfer();

    /// @notice Emitted when a chained call fails.
    error ChainedCallFailed();

    /// @notice Emitted when a payment is made.
    event PaymentMade(
        address indexed spender, address indexed productRecipient, uint256 indexed purchaseId, string productId
    );
}

interface IPayments is IPaymentsFunctions, IPaymentsSignals {}
