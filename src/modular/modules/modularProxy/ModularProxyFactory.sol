// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { ISignalsImplicitMode, Payload } from "../implicitSignals/ISignalsImplicitMode.sol";
import { IModularProxyFactory } from "./IModularProxyFactory.sol";
import { ModularProxy } from "./ModularProxy.sol";
import { Create2 } from "lib/openzeppelin-contracts/contracts/utils/Create2.sol";
import {
    Attestation,
    LibAttestation
} from "lib/signals-implicit-mode/lib/sequence-v3/src/extensions/sessions/implicit/Attestation.sol";

/// @title ModularProxyFactory
/// @author Michael Standen
/// @notice Factory for creating modular proxy instances.
contract ModularProxyFactory is IModularProxyFactory, ISignalsImplicitMode {

    using LibAttestation for Attestation;

    /// @inheritdoc IModularProxyFactory
    function deploy(uint256 nonce, address defaultImpl, address owner) external returns (ModularProxy) {
        (bytes32 salt, bytes memory creationCode) = _getDeployParams(nonce, defaultImpl, owner);
        address proxy = Create2.deploy(0, salt, creationCode);
        emit Deployed(proxy);
        return ModularProxy(payable(proxy));
    }

    /// @inheritdoc IModularProxyFactory
    function determineAddress(uint256 nonce, address defaultImpl, address owner) external view returns (address) {
        (bytes32 salt, bytes memory creationCode) = _getDeployParams(nonce, defaultImpl, owner);
        bytes32 bytecodeHash = keccak256(creationCode);
        return Create2.computeAddress(salt, bytecodeHash);
    }

    function _getDeployParams(
        uint256 nonce,
        address defaultImpl,
        address owner
    ) internal pure returns (bytes32 salt, bytes memory creationCode) {
        salt = keccak256(abi.encode(nonce, defaultImpl, owner));
        creationCode = abi.encodePacked(type(ModularProxy).creationCode, abi.encode(defaultImpl, owner));
        return (salt, creationCode);
    }

    /// @inheritdoc ISignalsImplicitMode
    function acceptImplicitRequest(
        address wallet,
        Attestation calldata attestation,
        Payload.Call calldata
    ) external pure returns (bytes32 magic) {
        // Allow implicit access for any domain
        return attestation.generateImplicitRequestMagic(wallet);
    }

}
