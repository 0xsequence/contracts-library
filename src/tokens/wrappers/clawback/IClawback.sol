// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IClawbackFunctions {

    enum TokenType {
        ERC20,
        ERC721,
        ERC1155
    }

    struct Template {
        bool destructionOnly;
        bool transferOpen;
        uint56 duration;
        address admin;
    }

    struct TokenDetails {
        TokenType tokenType;
        uint32 templateId;
        uint56 lockedAt;
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
    function wrap(
        uint32 templateId,
        TokenType tokenType,
        address tokenAddr,
        uint256 tokenId,
        uint256 amount,
        address receiver
    ) external returns (uint256 wrappedTokenId);

    /**
     * Add more tokens to a wrapping.
     * @param wrappedTokenId The wrapped token ID.
     * @param amount The amount to wrap.
     * @param receiver The receiver of the wrapped token.
     */
    function addToWrap(uint256 wrappedTokenId, uint256 amount, address receiver) external;

    /**
     * Unwraps a token.
     * @param wrappedTokenId The wrapped token ID.
     * @param holder The holder of the token.
     * @param amount The amount to unwrap.
     * @dev Unwrapped tokens are sent to the wrapped token holder.
     */
    function unwrap(uint256 wrappedTokenId, address holder, uint256 amount) external;

    /**
     * Clawback a token.
     * @param wrappedTokenId The wrapped token ID.
     * @param holder The holder of the token.
     * @param receiver The receiver of the token.
     * @param amount The amount to clawback.
     * @notice Only an operator of the template can clawback.
     * @notice Clawback is only allowed when the token is locked.
     */
    function clawback(uint256 wrappedTokenId, address holder, address receiver, uint256 amount) external;

    /**
     * Clawback unwrapped tokens without burning wrapped tokens.
     * @param wrappedTokenId The wrapped token ID.
     * @param receiver The receiver of the token.
     * @param amount The amount to clawback.
     * @notice Clawback rules apply.
     * @notice This function doesn't affect the wrapped token and should only be used when wrapped tokens are logically inaccessible.
     * @dev Clawing back an incomplete amount will lead to a race when unwrapping remaining tokens.
     */
    function emergencyClawback(uint256 wrappedTokenId, address receiver, uint256 amount) external;

    /**
     * Returns the details of a wrapped token.
     * @param wrappedTokenId The wrapped token ID.
     * @return The token details.
     */
    function getTokenDetails(
        uint256 wrappedTokenId
    ) external view returns (TokenDetails memory);

    // Template functions

    /**
     * Gets the details of a template.
     * @param templateId The template ID.
     * @return The template details.
     */
    function getTemplate(
        uint32 templateId
    ) external view returns (Template memory);

    /**
     * Add a new template.
     * @param duration The duration of the template.
     * @param destructionOnly Whether the template is for destruction only.
     * @param transferOpen Whether the template allows transfers.
     * @return templateId The template ID.
     * @notice The msg.sender will be set as the admin of this template.
     */
    function addTemplate(
        uint56 duration,
        bool destructionOnly,
        bool transferOpen
    ) external returns (uint32 templateId);

    /**
     * Update a template.
     * @param templateId The template ID.
     * @param duration The duration of the template. Can only be reduced.
     * @param destructionOnly Whether the template is for destruction only. Can only be updated from false to true.
     * @param transferOpen Whether the template allows transfers. Can only be updated from false to true.
     * @notice Only the admin of the template can update it.
     */
    function updateTemplate(uint32 templateId, uint56 duration, bool destructionOnly, bool transferOpen) external;

    /**
     * Add a transferer to a template.
     * @param templateId The template ID.
     * @param transferer The address of the transferer.
     * @notice Only the admin of the template can add a transferer.
     * @notice Transferers cannot be removed.
     * @notice Transfers are allowed when the to, from or operator is a template operator, even when the template is not in transferOpen mode.
     */
    function addTemplateTransferer(uint32 templateId, address transferer) external;

    /**
     * Update an operator to a template.
     * @param templateId The template ID.
     * @param operator The address of the operator.
     * @param allowed Whether the operator is allowed.
     * @notice Only the admin of the template can update an operator.
     */
    function updateTemplateOperator(uint32 templateId, address operator, bool allowed) external;

    /**
     * Transfer a template admin to another address.
     * @param templateId The template ID.
     * @param admin The address to transfer the template to.
     * @notice Only the admin of the template can transfer it.
     * @dev Transferring to address(0) is not allowed.
     */
    function updateTemplateAdmin(uint32 templateId, address admin) external;

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
        uint32 indexed templateId,
        address indexed tokenAddr,
        uint256 tokenId,
        uint256 amount,
        address sender,
        address receiver
    );

    /// @notice Emits when a token is unwrapped
    event Unwrapped(
        uint256 indexed wrappedTokenId,
        uint32 indexed templateId,
        address indexed tokenAddr,
        uint256 tokenId,
        uint256 amount,
        address sender
    );

    /// @notice Emits when a token is clawed back
    event ClawedBack(
        uint256 indexed wrappedTokenId,
        uint32 indexed templateId,
        address indexed tokenAddr,
        uint256 tokenId,
        uint256 amount,
        address operator,
        address holder,
        address receiver
    );

    /// @notice Emits when a token is clawed back via emergency
    event EmergencyClawedBack(
        uint256 indexed wrappedTokenId,
        uint32 indexed templateId,
        address indexed tokenAddr,
        uint256 tokenId,
        uint256 amount,
        address operator,
        address receiver
    );

    /// @notice Emits when a template is added
    event TemplateAdded(
        uint32 indexed templateId, address admin, uint56 duration, bool destructionOnly, bool transferOpen
    );

    /// @notice Emits when a template is updated
    event TemplateUpdated(uint32 indexed templateId, uint56 duration, bool destructionOnly, bool transferOpen);

    /// @notice Emits when a template admin is updated
    event TemplateAdminUpdated(uint32 indexed templateId, address admin);

    /// @notice Emits when a transferer is added
    event TemplateTransfererAdded(uint32 indexed templateId, address transferer);

    /// @notice Emits when an operator is updated
    event TemplateOperatorUpdated(uint32 indexed templateId, address operator, bool allowed);

}

// solhint-disable-next-line no-empty-blocks
interface IClawback is IClawbackFunctions, IClawbackSignals { }
