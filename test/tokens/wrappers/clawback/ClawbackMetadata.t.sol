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

        _hasProperty(properties, "originalName", erc20.name());
        _hasProperty(properties, "originalSymbol", erc20.symbol());
        _hasProperty(properties, "originalDecimals", erc20.decimals().toString());
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

        _hasProperty(properties, "tokenId", details.tokenId.toString());
        _hasProperty(properties, "originalName", erc721.name());
        _hasProperty(properties, "originalSymbol", erc721.symbol());
        _hasProperty(properties, "originalURI", erc721.tokenURI(details.tokenId));
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

        _hasProperty(properties, "tokenId", details.tokenId.toString());
        _hasProperty(properties, "originalURI", erc1155.uri(details.tokenId));
    }

    function _checkCommonProperties(
        ClawbackMetadata.MetadataProperty[] memory properties,
        IClawbackFunctions.TokenDetails memory details,
        IClawbackFunctions.Template memory template,
        string memory tokenTypeStr
    ) internal {
        _hasProperty(properties, "tokenType", tokenTypeStr);
        _hasProperty(properties, "tokenAddress", details.tokenAddr.toHexStringChecksummed());
        _hasProperty(properties, "templateId", details.templateId.toString());
        _hasProperty(properties, "lockedAt", details.lockedAt.toString());
        _hasProperty(properties, "destructionOnly", template.destructionOnly ? "true" : "false");
        _hasProperty(properties, "transferOpen", template.transferOpen ? "true" : "false");
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
