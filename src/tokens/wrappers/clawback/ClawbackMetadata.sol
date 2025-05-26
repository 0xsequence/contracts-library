// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { Duration } from "../../../utils/Duration.sol";
import { IMetadataProvider } from "../../common/IMetadataProvider.sol";
import { IClawbackFunctions } from "./IClawback.sol";

import { IERC1155MetadataURI } from "openzeppelin-contracts/contracts/interfaces/IERC1155MetadataURI.sol";
import { IERC20Metadata } from "openzeppelin-contracts/contracts/interfaces/IERC20Metadata.sol";
import { IERC721Metadata } from "openzeppelin-contracts/contracts/interfaces/IERC721Metadata.sol";
import { IERC165 } from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

import { Base64 } from "solady/utils/Base64.sol";
import { LibString } from "solady/utils/LibString.sol";

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
        uint256 len = properties.length;
        for (uint256 i = 0; i < len;) {
            if (i > 0) {
                json = json.concat(", ");
            }
            json = json.concat('"').concat(properties[i].key).concat('": "').concat(properties[i].value).concat('"');
            unchecked {
                ++i;
            }
        }
        json = json.concat("}}");

        //solhint-enable quotes

        return "data:application/json;base64,".concat(Base64.encode(bytes(json)));
    }

    function _toTokenTypeStr(
        IClawbackFunctions.TokenType tokenType
    ) internal pure returns (string memory) {
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
        properties = new MetadataProperty[](hasTokenId ? 9 : 8);
        properties[0] = MetadataProperty("token_type", _toTokenTypeStr(details.tokenType));
        properties[1] = MetadataProperty("token_address", details.tokenAddr.toHexStringChecksummed());
        properties[2] = MetadataProperty("template_id", details.templateId.toString());
        properties[3] = MetadataProperty("locked_at", details.lockedAt.toString());
        properties[4] = MetadataProperty("unlocks_in", _formatUnlocksIn(details.lockedAt, template.duration));
        properties[5] = MetadataProperty("duration", Duration.format(template.duration));
        properties[6] = MetadataProperty("destruction_only", _boolToString(template.destructionOnly));
        properties[7] = MetadataProperty("transfer_open", _boolToString(template.transferOpen));
        if (hasTokenId) {
            properties[8] = MetadataProperty("token_id", details.tokenId.toString());
        }

        // From contract
        if (details.tokenType == IClawbackFunctions.TokenType.ERC20) {
            properties = _safeAddStringProperty(
                properties, "original_name", details.tokenAddr, abi.encodeWithSelector(IERC20Metadata.name.selector)
            );
            properties = _safeAddStringProperty(
                properties, "original_symbol", details.tokenAddr, abi.encodeWithSelector(IERC20Metadata.symbol.selector)
            );
            properties = _safeAddUint256Property(
                properties,
                "original_decimals",
                details.tokenAddr,
                abi.encodeWithSelector(IERC20Metadata.decimals.selector)
            );
        } else if (details.tokenType == IClawbackFunctions.TokenType.ERC721) {
            properties = _safeAddStringProperty(
                properties, "original_name", details.tokenAddr, abi.encodeWithSelector(IERC721Metadata.name.selector)
            );
            properties = _safeAddStringProperty(
                properties,
                "original_symbol",
                details.tokenAddr,
                abi.encodeWithSelector(IERC721Metadata.symbol.selector)
            );
            properties = _safeAddStringProperty(
                properties,
                "original_URI",
                details.tokenAddr,
                abi.encodeWithSelector(IERC721Metadata.tokenURI.selector, details.tokenId)
            );
        } else if (details.tokenType == IClawbackFunctions.TokenType.ERC1155) {
            properties = _safeAddStringProperty(
                properties,
                "original_URI",
                details.tokenAddr,
                abi.encodeWithSelector(IERC1155MetadataURI.uri.selector, details.tokenId)
            );
        }
    }

    function _boolToString(
        bool value
    ) internal pure returns (string memory) {
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
        } catch { }
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
        } catch { }
        return properties;
    }

    function getStringProperty(
        string memory key,
        address tokenAddr,
        bytes calldata callData
    ) external view returns (MetadataProperty memory) {
        (bool success, bytes memory prop) = tokenAddr.staticcall(callData);
        if (success) {
            return MetadataProperty(key, abi.decode(prop, (string)));
        }
        // Unable to get property
        revert();
    }

    function getUint256Property(
        string memory key,
        address tokenAddr,
        bytes calldata callData
    ) external view returns (MetadataProperty memory) {
        (bool success, bytes memory prop) = tokenAddr.staticcall(callData);
        if (success) {
            return MetadataProperty(key, abi.decode(prop, (uint256)).toString());
        }
        // Unable to get property
        revert();
    }

    function _appendProperty(
        MetadataProperty[] memory properties,
        MetadataProperty memory prop
    ) internal pure returns (MetadataProperty[] memory) {
        MetadataProperty[] memory newProperties = new MetadataProperty[](properties.length + 1);
        uint256 len = properties.length;
        for (uint256 i = 0; i < len;) {
            newProperties[i] = properties[i];
            unchecked {
                ++i;
            }
        }
        newProperties[properties.length] = prop;
        return newProperties;
    }

    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceID
    ) public view virtual returns (bool) {
        if (interfaceID == type(IERC165).interfaceId || interfaceID == type(IMetadataProvider).interfaceId) {
            return true;
        }
        return false;
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

}
