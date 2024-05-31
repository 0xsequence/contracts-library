// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {ClawbackTestBase, IClawbackFunctions, ClawbackMetadata} from "./ClawbackTestBase.sol";
import {console, stdError} from "forge-std/Test.sol";

import {IMetadataProvider} from "src/tokens/common/IMetadataProvider.sol";

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
        assertEq(properties.length, 10);

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
        assertEq(properties.length, 11);

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
        assertEq(properties.length, 9);

        _checkCommonProperties(properties, details, template, "ERC-1155");

        _hasProperty(properties, "token_id", details.tokenId.toString());
        _hasProperty(properties, "original_URI", erc1155.uri(details.tokenId));
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
        _hasProperty(properties, "duration", template.duration.toString());
    }

    function _hasProperty(ClawbackMetadata.MetadataProperty[] memory properties, string memory key, string memory value)
        internal
    {
        bytes32 hasedKey = keccak256(abi.encodePacked(key));
        for (uint256 i = 0; i < properties.length; i++) {
            if (keccak256(abi.encodePacked(properties[i].key)) == hasedKey) {
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
