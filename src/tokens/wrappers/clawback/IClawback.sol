// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IClawbackFunctions {
    enum TokenType {
        ERC20,
        ERC721,
        ERC1155
    }

    struct Template {
        address admin;
        uint96 duration;
        bool destructionOnly;
        bool transferOpen;
    }

    struct TokenDetails {
        uint24 templateId;
        uint96 lockedAt;
        TokenType tokenType;
        address tokenAddr;
        uint256 tokenId; // 0 for ERC20
    }

    // Wrap functions

    /**
     * Wraps a token.
     * @param templateId The template ID.
     * @param tokenType The token type.
     * @param tokenAddr The token address.
     * @param tokenId The token ID.
     * @param amount The amount to wrap.
     * @param receiver The receiver of the wrapped token.
     * @return wrappedTokenId The wrapped token ID.
     */
    function wrap(uint24 templateId, TokenType tokenType, address tokenAddr, uint256 tokenId, uint256 amount, address receiver)
        external
        returns (uint256 wrappedTokenId);

    /**
     * Unwraps a token.
     * @param wrappedTokenId The wrapped token ID.
     * @param owner The owner of the token.
     * @param amount The amount to unwrap.
     * @dev Unwrapped tokens are sent to the wrapped token owner.
     */
    function unwrap(uint256 wrappedTokenId, address owner, uint256 amount) external;

    /**
     * Clawback a token.
     * @param wrappedTokenId The wrapped token ID.
     * @param owner The owner of the token.
     * @param receiver The receiver of the token.
     * @param amount The amount to clawback.
     * @notice Only an operator of the template can clawback.
     * @notice Clawback is only allowed when the token is locked.
     */
    function clawback(uint256 wrappedTokenId, address owner, address receiver, uint256 amount) external;

    /**
     * Returns the details of a wrapped token.
     * @param wrappedTokenId The wrapped token ID.
     * @return The token details.
     */
    function getTokenDetails(uint256 wrappedTokenId) external view returns (TokenDetails memory);

    // Template functions

    /**
     * Gets the details of a template.
     * @param templateId The template ID.
     * @return The template details.
     */
    function getTemplate(uint24 templateId) external view returns (Template memory);

    /**
     * Add a new template.
     * @param duration The duration of the template.
     * @param destructionOnly Whether the template is for destruction only.
     * @param transferOpen Whether the template allows transfers.
     * @return templateId The template ID.
     * @notice The msg.sender will be set as the admin of this template.
     */
    function addTemplate(uint96 duration, bool destructionOnly, bool transferOpen)
        external
        returns (uint24 templateId);

    /**
     * Update a template.
     * @param templateId The template ID.
     * @param duration The duration of the template. Can only be reduced.
     * @param destructionOnly Whether the template is for destruction only. Can only be updated from false to true.
     * @param transferOpen Whether the template allows transfers. Can only be updated from false to true.
     * @notice Only the admin of the template can update it.
     */
    function updateTemplate(uint24 templateId, uint96 duration, bool destructionOnly, bool transferOpen) external;

    /**
     * Add a transferer to a template.
     * @param templateId The template ID.
     * @param transferer The address of the transferer.
     * @notice Only the admin of the template can add a transferer.
     * @notice Transferers cannot be removed.
     */
    function addTemplateTransferer(uint24 templateId, address transferer) external;

    /**
     * Update an operator to a template.
     * @param templateId The template ID.
     * @param operator The address of the operator.
     * @param allowed Whether the operator is allowed.
     * @notice Only the admin of the template can update an operator.
     */
    function updateTemplateOperator(uint24 templateId, address operator, bool allowed) external;

    /**
     * Transfer a template admin to another address.
     * @param templateId The template ID.
     * @param admin The address to transfer the template to.
     * @notice Only the admin of the template can transfer it.
     * @dev Transferring to address(0) is not allowed.
     */
    function updateTemplateAdmin(uint24 templateId, address admin) external;
}

interface IClawbackSignals {
    /// @notice Thrown when the template ID is invalid
    error InvalidTemplate();

    /// @notice Thrown when token has not been approved
    error InvalidTokenApproval();

    /// @notice Thrown when token transfer is invalid
    error InvalidTokenTransfer();

    /// @notice Thrown when token is locked
    error TokenLocked();

    /// @notice Thrown when token is unlocked
    error TokenUnlocked();

    /// @notice Thrown when the caller is not authorized
    error Unauthorized();

    /// @notice Thrown when the receiver is invalid
    error InvalidReceiver();

    /// @notice Thrown when the template change is invalid
    error InvalidTemplateChange(string);

    /// @notice Emits when a token is wrapped
    event Wrapped(
        uint256 indexed wrappedTokenId,
        uint24 indexed templateId,
        address indexed tokenAddr,
        uint256 tokenId,
        uint256 amount,
        address sender,
        address receiver
    );

    /// @notice Emits when a token is unwrapped
    event Unwrapped(
        uint256 indexed wrappedTokenId,
        uint24 indexed templateId,
        address indexed tokenAddr,
        uint256 tokenId,
        uint256 amount,
        address sender
    );

    /// @notice Emits when a token is clawed back
    event ClawedBack(
        uint256 indexed wrappedTokenId,
        uint24 indexed templateId,
        address indexed tokenAddr,
        uint256 tokenId,
        uint256 amount,
        address operator,
        address owner,
        address receiver
    );

    /// @notice Emits when a template is added
    event TemplateAdded(
        uint24 indexed templateId, address admin, uint96 duration, bool destructionOnly, bool transferOpen
    );

    /// @notice Emits when a template is updated
    event TemplateUpdated(uint24 indexed templateId, uint96 duration, bool destructionOnly, bool transferOpen);

    /// @notice Emits when a template admin is updated
    event TemplateAdminUpdated(uint24 indexed templateId, address admin);

    /// @notice Emits when a transferer is added
    event TemplateTransfererAdded(uint24 indexed templateId, address transferer);

    /// @notice Emits when an operator is updated
    event TemplateOperatorUpdated(uint24 indexed templateId, address operator, bool allowed);
}

// solhint-disable-next-line no-empty-blocks
interface IClawback is IClawbackFunctions, IClawbackSignals {}
