// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IClawback, IClawbackFunctions} from "./IClawback.sol";
import {IERC721Transfer} from "../../common/IERC721Transfer.sol";
import {IMetadataProvider} from "../../common/IMetadataProvider.sol";

import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC1155Metadata} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155Metadata.sol";
import {ERC1155, ERC1155MintBurn} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155MintBurn.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract Clawback is Ownable, ERC1155MintBurn, IERC1155Metadata, IClawback {
    // Do not use address(0) as burn address due to common transfer restrictions.
    address public constant BURN_ADDRESS = address(0x000000000000000000000000000000000000dEaD);

    mapping(uint32 => Template) internal _templates;
    mapping(uint256 => TokenDetails) internal _tokenDetails;

    mapping(uint32 => mapping(address => bool)) public templateOperators;
    mapping(uint32 => mapping(address => bool)) public templateTransferers;

    IMetadataProvider public metadataProvider;

    bool private _expectingReceive; // Token receiver guard

    uint32 private _nextTemplateId;
    uint256 private _nextWrappedTokenId;

    modifier onlyTemplateAdmin(uint32 templateId) {
        if (_templates[templateId].admin != msg.sender) {
            revert Unauthorized();
        }
        _;
    }

    constructor(address ownerAddr, address metadataProviderAddr) {
        _transferOwnership(ownerAddr);
        metadataProvider = IMetadataProvider(metadataProviderAddr);
    }

    /// @inheritdoc IClawbackFunctions
    function getTokenDetails(uint256 wrappedTokenId) external view returns (TokenDetails memory) {
        return _tokenDetails[wrappedTokenId];
    }

    /// @inheritdoc IClawbackFunctions
    function getTemplate(uint32 templateId) external view returns (Template memory) {
        return _templates[templateId];
    }

    /// @inheritdoc IClawbackFunctions
    function wrap(
        uint32 templateId,
        TokenType tokenType,
        address tokenAddr,
        uint256 tokenId,
        uint256 amount,
        address receiver
    ) external returns (uint256 wrappedTokenId) {
        if (_templates[templateId].admin == address(0)) {
            revert InvalidTemplate();
        }
        if (tokenAddr == address(this)) {
            // Prevent rewrapping
            revert InvalidTokenTransfer();
        }

        wrappedTokenId = _nextWrappedTokenId++;
        // solhint-disable-next-line not-rely-on-time
        TokenDetails memory details = TokenDetails(tokenType, templateId, uint56(block.timestamp), tokenAddr, tokenId);
        _tokenDetails[wrappedTokenId] = details;

        address sender = msg.sender;
        _addToWrap(details, wrappedTokenId, sender, amount, receiver);
    }

    /// @inheritdoc IClawbackFunctions
    function addToWrap(uint256 wrappedTokenId, uint256 amount, address receiver) external {
        TokenDetails memory details = _tokenDetails[wrappedTokenId];
        if (details.tokenAddr == address(0)) {
            revert InvalidTokenTransfer();
        }

        address sender = msg.sender;
        _addToWrap(details, wrappedTokenId, sender, amount, receiver);
    }

    function _addToWrap(
        TokenDetails memory details,
        uint256 wrappedTokenId,
        address sender,
        uint256 amount,
        address receiver
    ) internal {
        _expectingReceive = true;
        _transferFromOther(details.tokenType, details.tokenAddr, sender, address(this), details.tokenId, amount);
        delete _expectingReceive;

        _mint(receiver, wrappedTokenId, amount, "");

        emit Wrapped(wrappedTokenId, details.templateId, details.tokenAddr, details.tokenId, amount, sender, receiver);
    }

    /// @inheritdoc IClawbackFunctions
    function unwrap(uint256 wrappedTokenId, address holder, uint256 amount) external {
        TokenDetails memory details = _tokenDetails[wrappedTokenId];
        Template memory template = _templates[details.templateId];
        address sender = msg.sender;
        if (holder != sender) {
            // Operators are permitted any time
            if (!templateOperators[details.templateId][sender]) {
                revert Unauthorized();
            }
            // solhint-disable-next-line not-rely-on-time
        } else if (block.timestamp - details.lockedAt < template.duration) {
            revert TokenLocked();
        }

        _burn(holder, wrappedTokenId, amount);
        _transferFromOther(details.tokenType, details.tokenAddr, address(this), holder, details.tokenId, amount);

        emit Unwrapped(wrappedTokenId, details.templateId, details.tokenAddr, details.tokenId, amount, sender);
    }

    /// @inheritdoc IClawbackFunctions
    function clawback(uint256 wrappedTokenId, address holder, address receiver, uint256 amount) external {
        TokenDetails memory details = _tokenDetails[wrappedTokenId];
        _verifyClawback(details, receiver);

        _burn(holder, wrappedTokenId, amount);
        _transferFromOther(details.tokenType, details.tokenAddr, address(this), receiver, details.tokenId, amount);

        emit ClawedBack(
            wrappedTokenId, details.templateId, details.tokenAddr, details.tokenId, amount, msg.sender, holder, receiver
        );
    }

    /// @inheritdoc IClawbackFunctions
    function emergencyClawback(uint256 wrappedTokenId, address receiver, uint256 amount) external {
        TokenDetails memory details = _tokenDetails[wrappedTokenId];
        _verifyClawback(details, receiver);

        // No burn
        _transferFromOther(details.tokenType, details.tokenAddr, address(this), receiver, details.tokenId, amount);

        emit EmergencyClawedBack(
            wrappedTokenId, details.templateId, details.tokenAddr, details.tokenId, amount, msg.sender, receiver
        );
    }

    function _verifyClawback(TokenDetails memory details, address receiver) internal view {
        Template memory template = _templates[details.templateId];
        if (!templateOperators[details.templateId][msg.sender]) {
            // Only allowed by operators
            revert Unauthorized();
        }
        // solhint-disable-next-line not-rely-on-time
        if (block.timestamp - details.lockedAt >= template.duration) {
            // Must be locked
            revert TokenUnlocked();
        }
        if (template.destructionOnly && receiver != BURN_ADDRESS) {
            revert InvalidReceiver();
        }
    }

    /// @inheritdoc IClawbackFunctions
    function addTemplate(uint56 duration, bool destructionOnly, bool transferOpen)
        external
        returns (uint32 templateId)
    {
        templateId = _nextTemplateId++;
        address admin = msg.sender;
        _templates[templateId] = Template(destructionOnly, transferOpen, duration, admin);
        emit TemplateAdded(templateId, admin, duration, destructionOnly, transferOpen);
    }

    /// @inheritdoc IClawbackFunctions
    function updateTemplate(uint32 templateId, uint56 duration, bool destructionOnly, bool transferOpen)
        external
        onlyTemplateAdmin(templateId)
    {
        Template storage template = _templates[templateId];
        if (duration > template.duration) {
            revert InvalidTemplateChange("Duration must be equal or decrease");
        }
        if (template.destructionOnly && !destructionOnly) {
            revert InvalidTemplateChange("Cannot change from destruction only");
        }
        if (template.transferOpen && !transferOpen) {
            revert InvalidTemplateChange("Cannot change from transfer open");
        }
        template.duration = duration;
        template.destructionOnly = destructionOnly;
        template.transferOpen = transferOpen;
        emit TemplateUpdated(templateId, duration, destructionOnly, transferOpen);
    }

    /// @inheritdoc IClawbackFunctions
    function updateTemplateAdmin(uint32 templateId, address admin) external onlyTemplateAdmin(templateId) {
        if (admin == address(0)) {
            revert InvalidTemplateChange("Admin cannot be zero address");
        }
        Template storage template = _templates[templateId];
        template.admin = admin;
        emit TemplateAdminUpdated(templateId, admin);
    }

    /// @inheritdoc IClawbackFunctions
    function addTemplateTransferer(uint32 templateId, address transferer) external onlyTemplateAdmin(templateId) {
        templateTransferers[templateId][transferer] = true;
        emit TemplateTransfererAdded(templateId, transferer);
    }

    /// @inheritdoc IClawbackFunctions
    function updateTemplateOperator(uint32 templateId, address operator, bool allowed)
        external
        onlyTemplateAdmin(templateId)
    {
        templateOperators[templateId][operator] = allowed;
        emit TemplateOperatorUpdated(templateId, operator, allowed);
    }

    /**
     * Transfer tokens from one address to another.
     * @param from Source address.
     * @param to Target address.
     * @param wrappedTokenId ID of the token type.
     * @param amount Transfered amount.
     * @param data Additional data with no specified format.
     */
    function safeTransferFrom(address from, address to, uint256 wrappedTokenId, uint256 amount, bytes memory data)
        public
        override
    {
        TokenDetails memory details = _tokenDetails[wrappedTokenId];
        Template memory template = _templates[details.templateId];
        if (!template.transferOpen) {
            bool isTransferer = templateTransferers[details.templateId][msg.sender]
                || templateTransferers[details.templateId][from] || templateTransferers[details.templateId][to];
            if (!isTransferer) {
                // Transfer not allowed
                revert Unauthorized();
            }
        }
        super.safeTransferFrom(from, to, wrappedTokenId, amount, data);
    }

    /**
     * Batch transfer tokens from one address to another.
     * @param from Source address.
     * @param to Target address.
     * @param wrappedTokenIds IDs of the token type.
     * @param amounts Transfered amounts.
     * @param data Additional data with no specified format.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory wrappedTokenIds,
        uint256[] memory amounts,
        bytes memory data
    ) public override {
        uint256 len = wrappedTokenIds.length;
        for (uint256 i = 0; i < len;) {
            uint256 wrappedTokenId = wrappedTokenIds[i];
            TokenDetails memory details = _tokenDetails[wrappedTokenId];
            Template memory template = _templates[details.templateId];
            if (!template.transferOpen) {
                bool isTransferer = templateTransferers[details.templateId][msg.sender]
                    || templateTransferers[details.templateId][from] || templateTransferers[details.templateId][to];
                if (!isTransferer) {
                    // Transfer not allowed
                    revert Unauthorized();
                }
            }
            unchecked {
                ++i;
            }
        }
        super.safeBatchTransferFrom(from, to, wrappedTokenIds, amounts, data);
    }

    function _transferFromOther(
        TokenType tokenType,
        address tokenAddr,
        address from,
        address to,
        uint256 tokenId,
        uint256 amount
    ) private {
        if (tokenType == TokenType.ERC1155) {
            if (amount == 0) {
                revert InvalidTokenTransfer();
            }
            // ERC-1155
            IERC1155(tokenAddr).safeTransferFrom(from, to, tokenId, amount, "");
        } else if (tokenType == TokenType.ERC721) {
            // ERC721
            if (amount != 1) {
                revert InvalidTokenTransfer();
            }
            IERC721Transfer(tokenAddr).safeTransferFrom(from, to, tokenId);
        } else if (tokenType == TokenType.ERC20) {
            if (tokenId != 0 || amount == 0) {
                revert InvalidTokenTransfer();
            }
            if (from == address(this)) {
                SafeTransferLib.safeTransfer(tokenAddr, to, amount);
            } else {
                SafeTransferLib.safeTransferFrom(tokenAddr, from, to, amount);
            }
        } else {
            revert InvalidTokenTransfer();
        }
    }

    // URI

    function updateMetadataProvider(address metadataProviderAddr) external onlyOwner {
        metadataProvider = IMetadataProvider(metadataProviderAddr);
    }

    function uri(uint256 wrappedTokenId) external view override returns (string memory) {
        return metadataProvider.metadata(address(this), wrappedTokenId);
    }

    // Receiver

    modifier expectedReceive() {
        if (!_expectingReceive) {
            revert InvalidReceiver();
        }
        _;
        delete _expectingReceive;
    }

    function onERC721Received(address, address, uint256, bytes calldata) external expectedReceive returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata)
        external
        expectedReceive
        returns (bytes4)
    {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        // Unused.
        revert InvalidReceiver();
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 _interfaceID) public view virtual override returns (bool) {
        if (
            _interfaceID == type(IClawback).interfaceId || _interfaceID == type(IClawbackFunctions).interfaceId
                || _interfaceID == type(IERC1155Metadata).interfaceId
        ) {
            return true;
        }
        return super.supportsInterface(_interfaceID);
    }
}
