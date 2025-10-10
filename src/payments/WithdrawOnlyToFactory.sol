// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { WithdrawOnlyTo } from "./WithdrawOnlyTo.sol";

import { Clones } from "openzeppelin-contracts/contracts/proxy/Clones.sol";

contract WithdrawOnlyToFactory {

    using Clones for address;

    event WithdrawOnlyToDeployed(address proxyAddr);

    address public immutable implementation;

    constructor() {
        implementation = address(new WithdrawOnlyTo(address(0)));
    }

    function deploy(
        address withdrawTo
    ) external returns (address proxyAddr) {
        proxyAddr = implementation.cloneDeterministic(keccak256(abi.encode(withdrawTo)));
        WithdrawOnlyTo(payable(proxyAddr)).initialize(withdrawTo);
        emit WithdrawOnlyToDeployed(proxyAddr);
        return proxyAddr;
    }

    function determineAddress(
        address withdrawTo
    ) external view returns (address proxyAddr) {
        return implementation.predictDeterministicAddress(keccak256(abi.encode(withdrawTo)));
    }

}
