// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IExtension, IExtensionMetadata } from "../../interfaces/IExtensionMetadata.sol";
import { LibBytes } from "../../utils/LibBytes.sol";
import { SignalsImplicitModeStorage } from "./SignalsImplicitModeStorage.sol";
import {
    Attestation,
    ISignalsImplicitMode,
    Payload
} from "lib/signals-implicit-mode/lib/sequence-v3/src/extensions/sessions/implicit/ISignalsImplicitMode.sol";
import { IImplicitProjectValidation } from "lib/signals-implicit-mode/src/registry/IImplicitProjectValidation.sol";

/// @title SignalsImplicitMode
/// @author Michael Standen
/// @notice Enable implicit mode validation by project
contract SignalsImplicitMode is ISignalsImplicitMode, IExtensionMetadata {

    /// @inheritdoc ISignalsImplicitMode
    function acceptImplicitRequest(
        address wallet,
        Attestation calldata attestation,
        Payload.Call calldata
    ) external view returns (bytes32) {
        SignalsImplicitModeStorage.Data storage data = SignalsImplicitModeStorage.load();
        IImplicitProjectValidation validator = IImplicitProjectValidation(data.validator);
        return validator.validateAttestation(wallet, attestation, data.projectId);
    }

    /// @inheritdoc IExtension
    /// @param initData Encoded validator and project id
    function onAddExtension(
        bytes calldata initData
    ) public virtual override {
        if (initData.length > 0) {
            uint256 pointer = 0;
            address validator;
            (validator, pointer) = LibBytes.readAddress(initData, pointer);
            (bytes32 projectId,) = LibBytes.readBytes32(initData, pointer);
            SignalsImplicitModeStorage.Data storage data = SignalsImplicitModeStorage.load();
            data.validator = validator;
            data.projectId = projectId;
        }
    }

    /// @inheritdoc IExtensionMetadata
    function getMetadata() public pure virtual override returns (ExtensionMetadata memory metadata) {
        return ExtensionMetadata({
            name: "SignalsImplicitMode",
            version: "1.0.0",
            description: "Implicit mode validation by project",
            author: "Sequence",
            url: "https://github.com/0xsequence/contracts-library.git"
        });
    }

    /// @inheritdoc IExtension
    function extensionSupport() public pure virtual override returns (ExtensionSupport memory support) {
        support.interfaces = new bytes4[](1);
        support.interfaces[0] = type(ISignalsImplicitMode).interfaceId;
        support.selectors = new bytes4[](1);
        support.selectors[0] = ISignalsImplicitMode.acceptImplicitRequest.selector;
        return support;
    }

}
