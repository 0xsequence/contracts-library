// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { DefaultProxy } from "./DefaultProxy.sol";
import { IDefaultProxyFactory } from "./IDefaultProxyFactory.sol";
import { Create2 } from "lib/openzeppelin-contracts/contracts/utils/Create2.sol";

/// @title DefaultProxyFactory
/// @author Michael Standen
/// @notice Factory for creating DefaultProxy instances
contract DefaultProxyFactory is IDefaultProxyFactory {

    /// @inheritdoc IDefaultProxyFactory
    function deploy(uint256 nonce, address defaultImpl, address owner) external returns (DefaultProxy) {
        (bytes32 salt, bytes memory creationCode) = _getDeployParams(nonce, defaultImpl, owner);
        address proxy = Create2.deploy(0, salt, creationCode);
        emit Deployed(proxy);
        return DefaultProxy(payable(proxy));
        //FIXME Add initData to this?
    }

    /// @inheritdoc IDefaultProxyFactory
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
        creationCode = abi.encodePacked(type(DefaultProxy).creationCode, abi.encode(defaultImpl, owner));
        return (salt, creationCode);
    }

}
