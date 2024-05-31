// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IMetadataProvider} from "../../common/IMetadataProvider.sol";
import {IClawbackFunctions} from "./IClawback.sol";

import {LibString} from "solady/utils/LibString.sol";
import {Base64} from "solady/utils/Base64.sol";

import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";

import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/interfaces/IERC721Metadata.sol";
import {IERC1155MetadataURI} from "@openzeppelin/contracts/interfaces/IERC1155MetadataURI.sol";

error InvalidTokenType();

contract ClawbackMetadata is IMetadataProvider, IERC165 {
    using LibString for *;

    struct MetadataProperty {
        string key;
        string value;
    }

    function metadata(address clawbackAddr, uint256 wrappedTokenId) external view returns (string memory) {
        IClawbackFunctions clawback = IClawbackFunctions(clawbackAddr);

        IClawbackFunctions.TokenDetails memory details = clawback.getTokenDetails(wrappedTokenId);
        IClawbackFunctions.Template memory template = clawback.getTemplate(details.templateId);

        string memory tokenTypeStr = _toTokenTypeStr(details.tokenType);

        //solhint-disable quotes

        string memory json = '{"name": "Clawback Asset #'.concat(wrappedTokenId.toString()).concat(
            '", "description": "A wrapped asset of '
        ).concat(tokenTypeStr).concat(" ").concat(details.tokenAddr.toHexStringChecksummed()).concat(" #").concat(
            details.tokenId.toString()
        ).concat('", "image": "", "decimals": 0, "properties": {');

        MetadataProperty[] memory properties = metadataProperties(details, template);
        for (uint256 i = 0; i < properties.length; i++) {
            if (i > 0) {
                json = json.concat(", ");
            }
            json = json.concat('"').concat(properties[i].key).concat('": "').concat(properties[i].value).concat('"');
        }
        json = json.concat("}}");

        //solhint-enable quotes

        return "data:application/json;base64,".concat(Base64.encode(bytes(json)));
    }

    function _toTokenTypeStr(IClawbackFunctions.TokenType tokenType) internal pure returns (string memory) {
        if (tokenType == IClawbackFunctions.TokenType.ERC20) {
            return "ERC-20";
        } else if (tokenType == IClawbackFunctions.TokenType.ERC721) {
            return "ERC-721";
        } else if (tokenType == IClawbackFunctions.TokenType.ERC1155) {
            return "ERC-1155";
        }
        revert InvalidTokenType();
    }

    function metadataProperties(
        IClawbackFunctions.TokenDetails memory details,
        IClawbackFunctions.Template memory template
    ) public view returns (MetadataProperty[] memory properties) {
        // From clawback
        bool hasTokenId = details.tokenType == IClawbackFunctions.TokenType.ERC721
            || details.tokenType == IClawbackFunctions.TokenType.ERC1155;
        properties = new MetadataProperty[](hasTokenId ? 8 : 7);
        properties[0] = MetadataProperty("tokenType", _toTokenTypeStr(details.tokenType));
        properties[1] = MetadataProperty("tokenAddress", details.tokenAddr.toHexStringChecksummed());
        properties[2] = MetadataProperty("templateId", details.templateId.toString());
        properties[3] = MetadataProperty("lockedAt", details.lockedAt.toString());
        properties[4] = MetadataProperty("duration", template.duration.toString());
        properties[5] = MetadataProperty("destructionOnly", _boolToString(template.destructionOnly));
        properties[6] = MetadataProperty("transferOpen", _boolToString(template.transferOpen));
        if (hasTokenId) {
            properties[7] = MetadataProperty("tokenId", details.tokenId.toString());
        }

        // From contract
        if (details.tokenType == IClawbackFunctions.TokenType.ERC20) {
            properties = _safeAddStringProperty(
                properties, "originalName", details.tokenAddr, abi.encodeWithSelector(IERC20Metadata.name.selector)
            );
            properties = _safeAddStringProperty(
                properties, "originalSymbol", details.tokenAddr, abi.encodeWithSelector(IERC20Metadata.symbol.selector)
            );
            properties = _safeAddUint256Property(
                properties,
                "originalDecimals",
                details.tokenAddr,
                abi.encodeWithSelector(IERC20Metadata.decimals.selector)
            );
        } else if (details.tokenType == IClawbackFunctions.TokenType.ERC721) {
            properties = _safeAddStringProperty(
                properties, "originalName", details.tokenAddr, abi.encodeWithSelector(IERC721Metadata.name.selector)
            );
            properties = _safeAddStringProperty(
                properties, "originalSymbol", details.tokenAddr, abi.encodeWithSelector(IERC721Metadata.symbol.selector)
            );
            properties = _safeAddStringProperty(
                properties,
                "originalURI",
                details.tokenAddr,
                abi.encodeWithSelector(IERC721Metadata.tokenURI.selector, details.tokenId)
            );
        } else if (details.tokenType == IClawbackFunctions.TokenType.ERC1155) {
            properties = _safeAddStringProperty(
                properties,
                "originalURI",
                details.tokenAddr,
                abi.encodeWithSelector(IERC1155MetadataURI.uri.selector, details.tokenId)
            );
        }
    }

    function _boolToString(bool value) internal pure returns (string memory) {
        return value ? "true" : "false";
    }

    function _safeAddStringProperty(
        MetadataProperty[] memory properties,
        string memory key,
        address tokenAddr,
        bytes memory callData
    ) internal view returns (MetadataProperty[] memory) {
        try this.getStringProperty(key, tokenAddr, callData) returns (MetadataProperty memory prop) {
            properties = _appendProperty(properties, prop);
        } catch {}
        return properties;
    }

    function _safeAddUint256Property(
        MetadataProperty[] memory properties,
        string memory key,
        address tokenAddr,
        bytes memory callData
    ) internal view returns (MetadataProperty[] memory) {
        try this.getUint256Property(key, tokenAddr, callData) returns (MetadataProperty memory prop) {
            properties = _appendProperty(properties, prop);
        } catch {}
        return properties;
    }

    function getStringProperty(string memory key, address tokenAddr, bytes calldata callData)
        external
        view
        returns (MetadataProperty memory)
    {
        (bool success, bytes memory prop) = tokenAddr.staticcall(callData);
        if (success) {
            return MetadataProperty(key, abi.decode(prop, (string)));
        }
        // Unable to get property
        revert();
    }

    function getUint256Property(string memory key, address tokenAddr, bytes calldata callData)
        external
        view
        returns (MetadataProperty memory)
    {
        (bool success, bytes memory prop) = tokenAddr.staticcall(callData);
        if (success) {
            return MetadataProperty(key, abi.decode(prop, (uint256)).toString());
        }
        // Unable to get property
        revert();
    }

    function _appendProperty(MetadataProperty[] memory properties, MetadataProperty memory prop)
        internal
        pure
        returns (MetadataProperty[] memory)
    {
        MetadataProperty[] memory newProperties = new MetadataProperty[](properties.length + 1);
        for (uint256 i = 0; i < properties.length; i++) {
            newProperties[i] = properties[i];
        }
        newProperties[properties.length] = prop;
        return newProperties;
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceID) public view virtual returns (bool) {
        if (interfaceID == type(IERC165).interfaceId || interfaceID == type(IMetadataProvider).interfaceId) {
            return true;
        }
        return false;
    }
}
