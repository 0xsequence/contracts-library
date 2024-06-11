// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ClawbackTestBase, IClawbackFunctions, ClawbackMetadata} from "./ClawbackTestBase.sol";
import {console, stdError} from "forge-std/Test.sol";

import {IMetadataProvider} from "src/tokens/common/IMetadataProvider.sol";
import {Duration} from "src/utils/Duration.sol";

import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";

import {LibString} from "solady/utils/LibString.sol";

contract ClawbackMetadataTest is ClawbackTestBase {
    using LibString for *;

    struct DetailsParam {
        uint8 tokenType;
        uint32 templateId;
        uint56 lockedAt;
        uint256 tokenId;
    }

    function _paramToDetails(DetailsParam memory param)
        internal
        view
        returns (IClawbackFunctions.TokenDetails memory)
    {
        IClawbackFunctions.TokenType tokenType = _toTokenType(param.tokenType);
        address tokenAddr;
        if (tokenType == IClawbackFunctions.TokenType.ERC20) {
            tokenAddr = address(erc20);
        } else if (tokenType == IClawbackFunctions.TokenType.ERC721) {
            tokenAddr = address(erc721);
        } else {
            tokenAddr = address(erc1155);
        }
        return IClawbackFunctions.TokenDetails({
            tokenType: tokenType,
            templateId: param.templateId,
            lockedAt: param.lockedAt,
            tokenAddr: tokenAddr,
            tokenId: param.tokenId
        });
    }

    function testMetadataPropertiesERC20(DetailsParam memory detailsParam, IClawbackFunctions.Template memory template)
        public
    {
        IClawbackFunctions.TokenDetails memory details = _paramToDetails(detailsParam);
        details.tokenType = IClawbackFunctions.TokenType.ERC20;
        details.tokenAddr = address(erc20);

        ClawbackMetadata.MetadataProperty[] memory properties = clawbackMetadata.metadataProperties(details, template);
        assertEq(properties.length, 11);

        _checkCommonProperties(properties, details, template, "ERC-20");

        _hasProperty(properties, "original_name", erc20.name());
        _hasProperty(properties, "original_symbol", erc20.symbol());
        _hasProperty(properties, "original_decimals", erc20.decimals().toString());
    }

    function testMetadataPropertiesERC721(DetailsParam memory detailsParam, IClawbackFunctions.Template memory template)
        public
    {
        IClawbackFunctions.TokenDetails memory details = _paramToDetails(detailsParam);
        details.tokenType = IClawbackFunctions.TokenType.ERC721;
        details.tokenAddr = address(erc721);
        details.tokenId = _bound(details.tokenId, 1, type(uint256).max);

        erc721.mint(address(this), details.tokenId, 1);

        ClawbackMetadata.MetadataProperty[] memory properties = clawbackMetadata.metadataProperties(details, template);
        assertEq(properties.length, 12);

        _checkCommonProperties(properties, details, template, "ERC-721");

        _hasProperty(properties, "token_id", details.tokenId.toString());
        _hasProperty(properties, "original_name", erc721.name());
        _hasProperty(properties, "original_symbol", erc721.symbol());
        _hasProperty(properties, "original_URI", erc721.tokenURI(details.tokenId));
    }

    function testMetadataPropertiesERC1155(
        DetailsParam memory detailsParam,
        IClawbackFunctions.Template memory template
    ) public {
        IClawbackFunctions.TokenDetails memory details = _paramToDetails(detailsParam);
        details.tokenType = IClawbackFunctions.TokenType.ERC1155;
        details.tokenAddr = address(erc1155);

        ClawbackMetadata.MetadataProperty[] memory properties = clawbackMetadata.metadataProperties(details, template);
        assertEq(properties.length, 10);

        _checkCommonProperties(properties, details, template, "ERC-1155");

        _hasProperty(properties, "token_id", details.tokenId.toString());
        _hasProperty(properties, "original_URI", erc1155.uri(details.tokenId));
    }

    function testDurationAndUnlocksAt() public {
        IClawbackFunctions.TokenDetails memory details;
        IClawbackFunctions.Template memory template;

        vm.warp(1688184000);

        details.lockedAt = uint56(block.timestamp - 1 days);
        template.duration = uint56(1 days);

        ClawbackMetadata.MetadataProperty[] memory properties;

        // Test when details.lockedAt is set to more than duration ago (unlocked)
        details.lockedAt = uint56(block.timestamp - 200 days);
        properties = clawbackMetadata.metadataProperties(details, template);
        _hasProperty(properties, "unlocks_in", "Unlocked");
        _hasProperty(properties, "duration", "1 days");

        // Test when details.lockedAt is set to just now (locked for 1 day)
        details.lockedAt = uint56(block.timestamp);
        properties = clawbackMetadata.metadataProperties(details, template);
        _hasProperty(properties, "unlocks_in", "1 days");
        _hasProperty(properties, "duration", "1 days");

        // Test when template.duration is set to a very high value (never unlocks)
        template.duration = uint56(999999 days);
        properties = clawbackMetadata.metadataProperties(details, template);
        _hasProperty(properties, "unlocks_in", "Never");
        _hasProperty(properties, "duration", "999999 days");

        // Test when template.duration is set to a small value and almost unlocked
        template.duration = uint56(12);
        details.lockedAt = uint56(block.timestamp - 11);
        properties = clawbackMetadata.metadataProperties(details, template);
        _hasProperty(properties, "unlocks_in", "1 seconds");
        _hasProperty(properties, "duration", "12 seconds");

        // Test when template.duration is 0 (should be unlocked)
        template.duration = uint56(0);
        details.lockedAt = uint56(block.timestamp);
        properties = clawbackMetadata.metadataProperties(details, template);
        _hasProperty(properties, "unlocks_in", "Unlocked");
        _hasProperty(properties, "duration", "");

        // Test for multiple units (e.g., 1 day, 3 hours, and 30 minutes)
        template.duration = uint56(1 days + 3 hours + 30 minutes);
        details.lockedAt = uint56(block.timestamp - 30 minutes);
        properties = clawbackMetadata.metadataProperties(details, template);
        _hasProperty(properties, "unlocks_in", "1 days, 3 hours");
        _hasProperty(properties, "duration", "1 days, 3 hours, 30 minutes");

        // Test for a very short duration (e.g., 5 seconds)
        template.duration = uint56(5 seconds + 1 minutes);
        details.lockedAt = uint56(block.timestamp - 1 minutes);
        properties = clawbackMetadata.metadataProperties(details, template);
        _hasProperty(properties, "unlocks_in", "5 seconds");
        _hasProperty(properties, "duration", "1 minutes, 5 seconds");

        // Test when duration includes all units (days, hours, minutes, and seconds)
        template.duration = uint56(2 days + 5 hours + 10 minutes + 15 seconds);
        details.lockedAt = uint56(block.timestamp);
        properties = clawbackMetadata.metadataProperties(details, template);
        _hasProperty(properties, "unlocks_in", "2 days, 5 hours, 10 minutes, 15 seconds");
        _hasProperty(properties, "duration", "2 days, 5 hours, 10 minutes, 15 seconds");

        // Test for unlocking after a period less than a day (e.g., 10 hours)
        template.duration = uint56(10 hours);
        details.lockedAt = uint56(block.timestamp - 8 hours);
        properties = clawbackMetadata.metadataProperties(details, template);
        _hasProperty(properties, "unlocks_in", "2 hours");
        _hasProperty(properties, "duration", "10 hours");
    }

    function _checkCommonProperties(
        ClawbackMetadata.MetadataProperty[] memory properties,
        IClawbackFunctions.TokenDetails memory details,
        IClawbackFunctions.Template memory template,
        string memory tokenTypeStr
    ) internal {
        _hasProperty(properties, "token_type", tokenTypeStr);
        _hasProperty(properties, "token_address", details.tokenAddr.toHexStringChecksummed());
        _hasProperty(properties, "template_id", details.templateId.toString());
        _hasProperty(properties, "locked_at", details.lockedAt.toString());
        _hasProperty(properties, "destruction_only", template.destructionOnly ? "true" : "false");
        _hasProperty(properties, "transfer_open", template.transferOpen ? "true" : "false");
        _hasProperty(properties, "duration", Duration.format(template.duration));
        _hasProperty(properties, "unlocks_in", _formatUnlocksIn(details.lockedAt, template.duration));
    }

    function _formatUnlocksIn(uint256 lockedAt, uint256 duration) internal view returns (string memory) {
        uint256 unlocksAt = lockedAt + duration;
        if (block.timestamp >= unlocksAt) {
            return "Unlocked";
        }

        uint256 remaining = unlocksAt - block.timestamp;
        if (remaining >= 999999 days) {
            return "Never";
        }

        return Duration.format(remaining);
    }

    function _hasProperty(ClawbackMetadata.MetadataProperty[] memory properties, string memory key, string memory value)
        internal
    {
        bytes32 hashedKey = keccak256(abi.encodePacked(key));
        for (uint256 i = 0; i < properties.length; i++) {
            if (keccak256(abi.encodePacked(properties[i].key)) == hashedKey) {
                assertEq(properties[i].value, value, key);
                return;
            }
        }
        // Not found
        fail();
    }

    //
    // Supports Interface
    //
    function testSupportsInterface() public view {
        assertTrue(clawbackMetadata.supportsInterface(type(IMetadataProvider).interfaceId));
        assertTrue(clawbackMetadata.supportsInterface(type(IERC165).interfaceId));
    }
}
