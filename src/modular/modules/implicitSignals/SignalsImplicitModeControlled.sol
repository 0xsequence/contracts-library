// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { LibBytes } from "../../utils/LibBytes.sol";
import { ModuleSupportUtils } from "../../utils/ModuleSupportUtils.sol";
import { AccessControlInternal } from "../accessControl/AccessControlInternal.sol";
import { ISignalsImplicitModeControlled } from "./ISignalsImplicitModeControlled.sol";
import { SignalsImplicitMode } from "./SignalsImplicitMode.sol";
import { SignalsImplicitModeStorage } from "./SignalsImplicitModeStorage.sol";

/// @title SignalsImplicitModeControlled
/// @author Michael Standen
/// @notice Enable implicit mode validation by project
contract SignalsImplicitModeControlled is AccessControlInternal, SignalsImplicitMode, ISignalsImplicitModeControlled {

    bytes32 internal constant _IMPLICIT_MODE_ADMIN_ROLE = keccak256("IMPLICIT_MODE_ADMIN_ROLE");

    /// @inheritdoc ISignalsImplicitModeControlled
    function setImplicitModeValidator(
        address validator
    ) external onlyRole(_IMPLICIT_MODE_ADMIN_ROLE) {
        SignalsImplicitModeStorage.Data storage data = SignalsImplicitModeStorage.load();
        data.validator = validator;
    }

    /// @inheritdoc ISignalsImplicitModeControlled
    function setImplicitModeProjectId(
        bytes32 projectId
    ) external onlyRole(_IMPLICIT_MODE_ADMIN_ROLE) {
        SignalsImplicitModeStorage.Data storage data = SignalsImplicitModeStorage.load();
        data.projectId = projectId;
    }

    /// @inheritdoc SignalsImplicitMode
    /// @param initData Encoded admin, validator and project id
    function onAttachModule(
        bytes calldata initData
    ) public virtual override {
        if (initData.length > 0) {
            uint256 pointer = 0;
            address admin;
            (admin, pointer) = LibBytes.readAddress(initData, pointer);
            AccessControlInternal._setHasRole(_IMPLICIT_MODE_ADMIN_ROLE, admin, true);
            SignalsImplicitMode.onAttachModule(initData[pointer:]);
        }
    }

    /// @inheritdoc SignalsImplicitMode
    function getMetadata() public pure override returns (ModuleMetadata memory metadata) {
        metadata.name = "SignalsImplicitModeControlled";
        metadata.version = "1.0.0";
        metadata.description = "Implicit mode validation by project with admin controls";
        metadata.author = "Sequence";
        metadata.url = "https://github.com/0xsequence/contracts-library.git";
    }

    /// @inheritdoc SignalsImplicitMode
    function describeCapabilities() public pure override returns (ModuleSupport memory support) {
        ModuleSupport[] memory supers = new ModuleSupport[](2);
        // ISignalsImplicitModeControlled
        supers[0] = ModuleSupport(new bytes4[](1), new bytes4[](2));
        supers[0].interfaces[0] = type(ISignalsImplicitModeControlled).interfaceId;
        supers[0].selectors[0] = ISignalsImplicitModeControlled.setImplicitModeValidator.selector;
        supers[0].selectors[1] = ISignalsImplicitModeControlled.setImplicitModeProjectId.selector;
        // SignalsImplicitMode
        supers[1] = SignalsImplicitMode.describeCapabilities();
        return ModuleSupportUtils.flatten(supers);
    }

}
