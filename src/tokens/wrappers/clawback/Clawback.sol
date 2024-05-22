// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IClawback, IClawbackFunctions} from "./IClawback.sol";
import {IERC721Transfer} from "../../common/IERC721Transfer.sol";

import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {ERC1155Metadata} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155Metadata.sol";
import {ERC1155, ERC1155MintBurn} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155MintBurn.sol";

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract Clawback is ERC1155MintBurn, ERC1155Metadata, IClawback {
    //FIXME Arg in template?
    address public constant ALTERNATIVE_BURN_ADDRESS = address(0x000000000000000000000000000000000000dEaD);

    mapping(uint24 => Template) internal _templates;
    mapping(uint256 => TokenDetails) internal _tokenDetails;

    mapping(uint24 => mapping(address => bool)) public templateOperators;
    mapping(uint24 => mapping(address => bool)) public templateTransferers;

    uint24 private _nextTemplateId;
    uint256 private _nextWrappedTokenId;

    bool private _expectingReceive; // Token receiver guard

    constructor(string memory _name, string memory _baseURI) ERC1155Metadata(_name, _baseURI) {}

    /// @inheritdoc IClawbackFunctions
    function getTokenDetails(uint256 wrappedTokenId) external view returns (TokenDetails memory) {
        return _tokenDetails[wrappedTokenId];
    }

    /// @inheritdoc IClawbackFunctions
    function getTemplate(uint24 templateId) external view returns (Template memory) {
        return _templates[templateId];
    }

    /// @inheritdoc IClawbackFunctions
    function wrap(uint24 templateId, TokenType tokenType, address tokenAddr, uint256 tokenId, uint256 amount)
        public
        returns (uint256 wrappedTokenId)
    {
        if (_templates[templateId].admin == address(0)) {
            revert InvalidTemplate();
        }
        address sender = msg.sender;

        _expectingReceive = true;
        _transferFromOther(tokenType, tokenAddr, sender, address(this), tokenId, amount);
        delete _expectingReceive;

        wrappedTokenId = _nextWrappedTokenId++;

        // solhint-disable-next-line not-rely-on-time
        _tokenDetails[wrappedTokenId] = TokenDetails(templateId, uint96(block.timestamp), tokenType, tokenAddr, tokenId);
        _mint(sender, wrappedTokenId, amount, "");

        emit Wrapped(wrappedTokenId, templateId, tokenAddr, tokenId, amount, sender);
    }

    /// @inheritdoc IClawbackFunctions
    function unwrap(uint256 wrappedTokenId, address owner, uint256 amount) public {
        TokenDetails memory details = _tokenDetails[wrappedTokenId];
        Template memory template = _templates[details.templateId];
        address sender = msg.sender;
        if (owner != sender) {
            // Operators are permitted any time
            if (!templateOperators[details.templateId][sender]) {
                revert Unauthorized();
            }
            // solhint-disable-next-line not-rely-on-time
        } else if (block.timestamp - details.lockedAt < template.duration) {
            revert TokenLocked();
        }

        _burn(owner, wrappedTokenId, amount);
        _transferFromOther(details.tokenType, details.tokenAddr, address(this), owner, details.tokenId, amount);

        emit Unwrapped(wrappedTokenId, details.templateId, details.tokenAddr, details.tokenId, amount, sender);
    }

    /// @inheritdoc IClawbackFunctions
    function clawback(uint256 wrappedTokenId, address owner, address receiver, uint256 amount) public {
        TokenDetails memory details = _tokenDetails[wrappedTokenId];
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
        if (template.destructionOnly && receiver != address(0)) {
            revert InvalidReceiver();
        }

        _burn(owner, wrappedTokenId, amount);
        _transferFromOther(details.tokenType, details.tokenAddr, address(this), receiver, details.tokenId, amount);

        emit ClawedBack(
            wrappedTokenId, details.templateId, details.tokenAddr, details.tokenId, amount, msg.sender, owner, receiver
        );
    }

    /// @inheritdoc IClawbackFunctions
    function addTemplate(uint96 duration, bool destructionOnly, bool transferOpen) public returns (uint24 templateId) {
        templateId = _nextTemplateId++;
        address admin = msg.sender;
        _templates[templateId] = Template(admin, duration, destructionOnly, transferOpen);
        emit TemplateAdded(templateId, admin, duration, destructionOnly, transferOpen);
    }

    /// @inheritdoc IClawbackFunctions
    function updateTemplate(uint24 templateId, uint96 duration, bool destructionOnly, bool transferOpen) public {
        Template storage template = _templates[templateId];
        if (template.admin != msg.sender) {
            revert Unauthorized();
        }
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
    function updateTemplateAdmin(uint24 templateId, address admin) public {
        if (admin == address(0)) {
            revert InvalidTemplateChange("Admin cannot be zero address");
        }
        Template storage template = _templates[templateId];
        if (template.admin != msg.sender) {
            revert Unauthorized();
        }
        template.admin = admin;
        emit TemplateAdminUpdated(templateId, admin);
    }

    /// @inheritdoc IClawbackFunctions
    function addTemplateTransferer(uint24 templateId, address transferer) public {
        if (_templates[templateId].admin != msg.sender) {
            revert Unauthorized();
        }
        templateTransferers[templateId][transferer] = true;
        emit TemplateTransfererAdded(templateId, transferer);
    }

    /// @inheritdoc IClawbackFunctions
    function updateTemplateOperator(uint24 templateId, address operator, bool allowed) public {
        if (_templates[templateId].admin != msg.sender) {
            revert Unauthorized();
        }
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
        bool isTransferer = templateTransferers[details.templateId][msg.sender];
        if (!template.transferOpen && !isTransferer) {
            // Transfer not allowed
            revert Unauthorized();
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
        for (uint256 i = 0; i < wrappedTokenIds.length; i++) {
            uint256 wrappedTokenId = wrappedTokenIds[i];
            TokenDetails memory details = _tokenDetails[wrappedTokenId];
            Template memory template = _templates[details.templateId];
            bool isTransferer = templateTransferers[details.templateId][msg.sender];
            if (!template.transferOpen && !isTransferer) {
                // Transfer not allowed
                revert Unauthorized();
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
            try IERC1155(tokenAddr).safeTransferFrom(from, to, tokenId, amount, "") {}
            catch {
                if (to == address(0)) {
                    // Transfer to address(0) may be blocked. Send to alternative burn address instead
                    IERC1155(tokenAddr).safeTransferFrom(from, ALTERNATIVE_BURN_ADDRESS, tokenId, amount, "");
                } else {
                    revert InvalidTokenTransfer();
                }
            }
        } else if (tokenType == TokenType.ERC721) {
            // ERC721
            if (amount != 1) {
                revert InvalidTokenTransfer();
            }
            try IERC721Transfer(tokenAddr).safeTransferFrom(from, to, tokenId) {}
            catch {
                if (to == address(0)) {
                    // Transfer to address(0) may be blocked. Send to alternative burn address instead
                    IERC721Transfer(tokenAddr).safeTransferFrom(from, ALTERNATIVE_BURN_ADDRESS, tokenId);
                } else {
                    revert InvalidTokenTransfer();
                }
            }
        } else if (tokenType == TokenType.ERC20) {
            if (tokenId != 0 || amount == 0) {
                revert InvalidTokenTransfer();
            }
            if (from == address(this)) {
                if (to == address(0)) {
                    //FIXME Update this to try address(0) first
                    // Burn
                    SafeTransferLib.safeTransfer(tokenAddr, ALTERNATIVE_BURN_ADDRESS, amount);
                } else {
                    SafeTransferLib.safeTransfer(tokenAddr, to, amount);
                }
            } else {
                SafeTransferLib.safeTransferFrom(tokenAddr, from, to, amount);
            }
        } else {
            revert InvalidTokenTransfer();
        }
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
    function supportsInterface(bytes4 _interfaceID)
        public
        view
        virtual
        override(ERC1155, ERC1155Metadata)
        returns (bool)
    {
        if (_interfaceID == type(IClawback).interfaceId || _interfaceID == type(IClawbackFunctions).interfaceId) {
            return true;
        }
        return super.supportsInterface(_interfaceID);
    }
}
