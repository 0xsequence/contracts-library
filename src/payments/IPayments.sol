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
        // Unspecified additional data for the payment
        bytes additionalData;
    }

    /**
     * Make a payment for a product.
     * @param paymentDetails The payment details.
     * @param signature The signature of the payment.
     */
    function makePayment(PaymentDetails calldata paymentDetails, bytes calldata signature) external payable;

    /**
     * Check is a signature is valid.
     * @param paymentDetails The payment details.
     * @param signature The signature of the payment.
     * @return isValid True if the signature is valid.
     */
    function isValidSignature(PaymentDetails calldata paymentDetails, bytes calldata signature)
        external
        view
        returns (bool isValid);

    /**
     * Returns the hash of the payment details.
     * @param paymentDetails The payment details.
     * @return paymentHash The hash of the payment details for signing.
     */
    function hashPaymentDetails(PaymentDetails calldata paymentDetails) external view returns (bytes32 paymentHash);

    /**
     * Check if a payment has been accepted.
     * @param purchaseId The ID of the purchase.
     * @return accepted True if the payment has been accepted.
     */
    function paymentAccepted(uint256 purchaseId) external view returns (bool);
}

interface IPaymentsSignals {
    /// @notice Emitted when a payment is already accepted. This prevents double spending.
    error PaymentAlreadyAccepted();

    /// @notice Emitted when a signature is invalid.
    error InvalidSignature();

    /// @notice Emitted when a payment has expired.
    error PaymentExpired();

    /// @notice Emitted when a token transfer is invalid.
    error InvalidTokenTransfer();

    /// @notice Emitted when a payment is made.
    event PaymentMade(
        address indexed spender, address indexed productRecipient, uint256 indexed purchaseId, string productId
    );
}

interface IPayments is IPaymentsFunctions, IPaymentsSignals {}
