// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {IERC1967} from "./IERC1967.sol";
import {StorageSlot} from "../../utils/StorageSlot.sol";

contract Proxy is IERC1967 {
    bytes32 internal constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    /**
     * Initializes the contract, setting proxy implementation address.
     */
    constructor(address implementation) {
        _setImplementation(implementation);
        emit Upgraded(implementation);
    }

    /**
     * Forward calls to the proxy implementation contract.
     */
    receive() external payable {
        _proxy();
    }

    /**
     * Forward calls to the proxy implementation contract.
     */
    fallback() external payable {
        _proxy();
    }

    /**
     * Forward calls to the proxy implementation contract.
     */
    function _proxy() private {
        address target = _getImplementation();
        assembly { // solhint-disable-line no-inline-assembly
            let ptr := mload(0x40)
            calldatacopy(ptr, 0, calldatasize())
            let result := delegatecall(gas(), target, ptr, calldatasize(), 0, 0)
            let size := returndatasize()
            returndatacopy(ptr, 0, size)
            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }

    /**
     * Set the implementation address.
     * @param _implementation The address of the implementation contract.
     */
    function _setImplementation(address _implementation) internal {
        StorageSlot._getAddressSlot(IMPLEMENTATION_SLOT).value = _implementation;
    }

    /**
     * Returns the address of the current implementation.
     */
    function _getImplementation() internal view returns (address) {
        return StorageSlot._getAddressSlot(IMPLEMENTATION_SLOT).value;
    }
}
