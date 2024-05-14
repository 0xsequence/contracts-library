// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {
    TransparentUpgradeableBeaconProxy,
    ITransparentUpgradeableBeaconProxy
} from "./TransparentUpgradeableBeaconProxy.sol";

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

/**
 * An proxy factory that deploys upgradeable beacon proxies.
 * @dev The factory owner is able to upgrade the beacon implementation.
 * @dev Proxy deployers are able to override the beacon reference with their own.
 */
abstract contract SequenceProxyFactory is Ownable {
    UpgradeableBeacon public beacon;

    /**
     * Initialize a Sequence Proxy Factory.
     * @param implementation The initial beacon implementation.
     * @param factoryOwner The owner of the factory.
     */
    function _initialize(address implementation, address factoryOwner) internal {
        beacon = new UpgradeableBeacon(implementation);
        Ownable._transferOwnership(factoryOwner);
    }

    /**
     * Deploys and initializes a new proxy instance.
     * @param _salt The deployment salt.
     * @param _proxyOwner The owner of the proxy.
     * @param _data The initialization data.
     * @return proxyAddress The address of the deployed proxy.
     */
    function _createProxy(bytes32 _salt, address _proxyOwner, bytes memory _data)
        internal
        returns (address proxyAddress)
    {
        bytes32 saltedHash = keccak256(abi.encodePacked(_salt, _proxyOwner, address(beacon), _data));
        bytes memory bytecode = type(TransparentUpgradeableBeaconProxy).creationCode;

        proxyAddress = Create2.deploy(0, saltedHash, bytecode);
        ITransparentUpgradeableBeaconProxy(payable(proxyAddress)).initialize(_proxyOwner, address(beacon), _data);
    }

    /**
     * Computes the address of a proxy instance.
     * @param _salt The deployment salt.
     * @param _proxyOwner The owner of the proxy.
     * @return proxy The expected address of the deployed proxy.
     */
    function _computeProxyAddress(bytes32 _salt, address _proxyOwner, bytes memory _data)
        internal
        view
        returns (address)
    {
        bytes32 saltedHash = keccak256(abi.encodePacked(_salt, _proxyOwner, address(beacon), _data));
        bytes32 bytecodeHash = keccak256(type(TransparentUpgradeableBeaconProxy).creationCode);

        return Create2.computeAddress(saltedHash, bytecodeHash);
    }

    /**
     * Upgrades the beacon implementation.
     * @param implementation The new beacon implementation.
     */
    function upgradeBeacon(address implementation) public onlyOwner {
        beacon.upgradeTo(implementation);
    }
}
