// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {BeaconProxy, Proxy} from "./openzeppelin/BeaconProxy.sol";
import {TransparentUpgradeableProxy, ERC1967Proxy} from "./openzeppelin/TransparentUpgradeableProxy.sol";

interface ITransparentUpgradeableBeaconProxy {
    function initialize(address admin, address beacon, bytes memory data) external;
}

error InvalidInitialization();

contract TransparentUpgradeableBeaconProxy is TransparentUpgradeableProxy, BeaconProxy {
    /**
     * Decode the initialization data from the msg.data and call the initialize function.
     */
    function _dispatchInitialize() private returns (bytes memory) {
        _requireZeroValue();

        (address admin, address beacon, bytes memory data) = abi.decode(msg.data[4:], (address, address, bytes));
        initialize(admin, beacon, data);

        return "";
    }

    function initialize(address admin, address beacon, bytes memory data) internal {
        if (_admin() != address(0)) {
            // Redundant call. This function can only be called when the admin is not set.
            revert InvalidInitialization();
        }
        _changeAdmin(admin);
        _upgradeBeaconToAndCall(beacon, data, false);
    }

    /**
     * @dev If the admin is not set, the fallback function is used to initialize the proxy.
     * @dev If the admin is set, the fallback function is used to delegatecall the implementation.
     */
    function _fallback() internal override (TransparentUpgradeableProxy, Proxy) {
        if (_getAdmin() == address(0)) {
            bytes memory ret;
            bytes4 selector = msg.sig;
            if (selector == ITransparentUpgradeableBeaconProxy.initialize.selector) {
                ret = _dispatchInitialize();
                // solhint-disable-next-line no-inline-assembly
                assembly {
                    return(add(ret, 0x20), mload(ret))
                }
            }
            // When the admin is not set, the fallback function is used to initialize the proxy.
            revert InvalidInitialization();
        }
        TransparentUpgradeableProxy._fallback();
    }

    /**
     * Returns the current implementation address.
     * @dev This is the implementation address set by the admin, or the beacon implementation.
     */
    function _implementation() internal view override (ERC1967Proxy, BeaconProxy) returns (address) {
        address implementation = ERC1967Proxy._implementation();
        if (implementation != address(0)) {
            return implementation;
        }
        return BeaconProxy._implementation();
    }
}
