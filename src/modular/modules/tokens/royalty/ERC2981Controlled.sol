// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { LibBytes } from "../../../utils/LibBytes.sol";
import { AccessControlInternal } from "../../accessControl/AccessControlInternal.sol";
import { ERC2981 } from "./ERC2981.sol";
import { ERC2981Storage } from "./ERC2981Storage.sol";
import { IERC2981Controlled } from "./IERC2981Controlled.sol";

/// @title ERC2981Controlled
/// @author Michael Standen
/// @notice NFT Royalty Standard that allows updates by roles
contract ERC2981Controlled is ERC2981, IERC2981Controlled, AccessControlInternal {

    bytes32 internal constant _ROYALTY_ADMIN_ROLE = keccak256("ROYALTY_ADMIN_ROLE");

    /// @inheritdoc IERC2981Controlled
    function setDefaultRoyalty(address receiver, uint96 royaltyBps) external onlyRole(_ROYALTY_ADMIN_ROLE) {
        ERC2981Storage.Data storage data = ERC2981Storage.load();
        data.defaultRoyalty = ERC2981Storage.RoyaltyInfo(receiver, royaltyBps);
    }

    /// @inheritdoc IERC2981Controlled
    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 royaltyBps
    ) external onlyRole(_ROYALTY_ADMIN_ROLE) {
        ERC2981Storage.Data storage data = ERC2981Storage.load();
        data.tokenRoyalty[tokenId] = ERC2981Storage.RoyaltyInfo(receiver, royaltyBps);
    }

    /// @inheritdoc ERC2981
    function describeCapabilities() public pure override returns (ModuleSupport memory support) {
        ModuleSupport memory baseSupport = ERC2981.describeCapabilities();
        // Add interfaces
        support.interfaces = new bytes4[](baseSupport.interfaces.length + 1);
        for (uint256 i = 0; i < baseSupport.interfaces.length; i++) {
            support.interfaces[i] = baseSupport.interfaces[i];
        }
        support.interfaces[baseSupport.interfaces.length] = type(IERC2981Controlled).interfaceId;
        // Add selectors
        support.selectors = new bytes4[](baseSupport.selectors.length + 2);
        for (uint256 i = 0; i < baseSupport.selectors.length; i++) {
            support.selectors[i] = baseSupport.selectors[i];
        }
        support.selectors[baseSupport.selectors.length] = IERC2981Controlled.setDefaultRoyalty.selector;
        support.selectors[baseSupport.selectors.length + 1] = IERC2981Controlled.setTokenRoyalty.selector;
        return support;
    }

    /// @inheritdoc ERC2981
    /// @param initData ERC2981 init data prefixed with the admin address
    function onAttachModule(
        bytes calldata initData
    ) public override {
        if (initData.length >= 20) {
            uint256 pointer = 0;
            address admin;
            (admin, pointer) = LibBytes.readAddress(initData, pointer);
            _setHasRole(_ROYALTY_ADMIN_ROLE, admin, true);
            ERC2981.onAttachModule(initData[pointer:]);
        }
    }

}
