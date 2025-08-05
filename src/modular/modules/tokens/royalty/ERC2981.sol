// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IModule } from "../../../interfaces/IModule.sol";
import { LibBytes } from "../../../utils/LibBytes.sol";
import { ERC2981Storage } from "./ERC2981Storage.sol";
import { IERC2981 } from "./IERC2981.sol";

/// @title ERC2981
/// @author Michael Standen
/// @notice NFT Royalty Standard
contract ERC2981 is IERC2981, IModule {

    /// @inheritdoc IERC2981
    function royaltyInfo(
        uint256 tokenId,
        uint256 salePrice
    ) external view returns (address receiver, uint256 royaltyAmount) {
        ERC2981Storage.Data storage data = ERC2981Storage.load();
        ERC2981Storage.RoyaltyInfo memory royalty = data.tokenRoyalty[tokenId];
        if (royalty.receiver == address(0)) {
            royalty = data.defaultRoyalty;
        }
        return (royalty.receiver, (salePrice * royalty.royaltyBps) / 10000);
    }

    /// @inheritdoc IModule
    /// @param initData Default royalty info in the format of (receiver, royaltyBps)
    function onAttachModule(
        bytes calldata initData
    ) public virtual override {
        if (initData.length != 0) {
            uint256 pointer = 0;
            address receiver;
            (receiver, pointer) = LibBytes.readAddress(initData, pointer);
            (uint96 royaltyBps,) = LibBytes.readUint96(initData, pointer);
            ERC2981Storage.Data storage data = ERC2981Storage.load();
            data.defaultRoyalty = ERC2981Storage.RoyaltyInfo(receiver, royaltyBps);
        }
    }

    /// @inheritdoc IModule
    function describeCapabilities() public pure virtual override returns (ModuleSupport memory support) {
        support.interfaces = new bytes4[](1);
        support.interfaces[0] = type(IERC2981).interfaceId;
        support.selectors = new bytes4[](1);
        support.selectors[0] = IERC2981.royaltyInfo.selector;
        return support;
    }

}
