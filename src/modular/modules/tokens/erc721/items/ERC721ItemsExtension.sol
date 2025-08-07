// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IERC721Items, IERC721ItemsFunctions } from "../../../../../tokens/ERC721/presets/items/IERC721Items.sol";

import { ERC721Storage } from "../../../../bases/erc721/ERC721Storage.sol";
import { IModule } from "../../../../interfaces/IModule.sol";
import { ModuleSupportUtils } from "../../../../utils/ModuleSupportUtils.sol";
import { ERC721Burn } from "../burn/ERC721Burn.sol";
import { ERC721MintAccessControl } from "../mint/ERC721MintAccessControl.sol";

/// @title ERC721ItemsExtension
/// @author Michael Standen
/// @notice Module to enable original ERC721Items compatibility.
contract ERC721ItemsExtension is ERC721MintAccessControl, ERC721Burn, IERC721Items {

    /// @inheritdoc ERC721MintAccessControl
    function mint(address to, uint256 tokenId) public override(ERC721MintAccessControl, IERC721ItemsFunctions) {
        super.mint(to, tokenId);
    }

    /// @inheritdoc ERC721MintAccessControl
    function mintSequential(
        address to,
        uint256 amount
    ) public override(ERC721MintAccessControl, IERC721ItemsFunctions) {
        super.mintSequential(to, amount);
    }

    /// @inheritdoc IERC721ItemsFunctions
    function totalSupply() public view override(IERC721ItemsFunctions) returns (uint256) {
        return ERC721Storage.loadSupply().totalSupply;
    }

    /// @inheritdoc IModule
    function onAttachModule(
        bytes calldata initData
    ) public virtual override(ERC721MintAccessControl, ERC721Burn) {
        ERC721MintAccessControl.onAttachModule(initData);
    }

    /// @inheritdoc IModule
    function describeCapabilities()
        public
        pure
        virtual
        override(ERC721MintAccessControl, ERC721Burn)
        returns (ModuleSupport memory support)
    {
        ModuleSupport[] memory supers = new ModuleSupport[](3);
        // ERC721 Items
        supers[0] = ModuleSupport(new bytes4[](1), new bytes4[](1));
        supers[0].interfaces[0] = type(IERC721ItemsFunctions).interfaceId;
        supers[0].selectors[0] = IERC721ItemsFunctions.totalSupply.selector;

        // Inherited modules
        supers[1] = ERC721MintAccessControl.describeCapabilities();
        supers[2] = ERC721Burn.describeCapabilities();

        return ModuleSupportUtils.flatten(supers);
    }

}
