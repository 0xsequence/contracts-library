// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { TestHelper } from "../../TestHelper.sol";

import { SignalsImplicitModeControlled } from "src/tokens/common/SignalsImplicitModeControlled.sol";

import { IERC165 } from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

import { Attestation, AuthData } from "sequence-v3/src/extensions/sessions/implicit/Attestation.sol";
import { ISignalsImplicitMode } from "sequence-v3/src/extensions/sessions/implicit/ISignalsImplicitMode.sol";
import { Payload } from "sequence-v3/src/modules/Payload.sol";

import { IImplicitProjectValidation } from "signals-implicit-mode/src/registry/IImplicitProjectValidation.sol";

contract SignalsImplicitModeTest is TestHelper {

    MockSignalsImplicitMode private _signals;
    address private _owner;
    address private _validator;
    bytes32 private _projectId;

    function setUp() public {
        _signals = new MockSignalsImplicitMode();
        _owner = makeAddr("owner");
        _validator = makeAddr("validator");
        _projectId = bytes32(uint256(1));
    }

    function testInitialize() public {
        _signals.initialize(_owner, _validator, _projectId, false);
        assertTrue(_signals.hasRole(keccak256("IMPLICIT_MODE_ADMIN_ROLE"), _owner));
    }

    function testSupportsInterface() public view {
        assertTrue(_signals.supportsInterface(type(IERC165).interfaceId));
        assertTrue(_signals.supportsInterface(type(ISignalsImplicitMode).interfaceId));
    }

    function testAcceptImplicitRequestWithTransactionCall() public {
        _signals.initialize(_owner, _validator, _projectId, false);

        address wallet = makeAddr("wallet");
        Attestation memory attestation = Attestation({
            approvedSigner: makeAddr("signer"),
            identityType: bytes4(0x12345678),
            issuerHash: bytes32(uint256(1)),
            audienceHash: bytes32(uint256(2)),
            applicationData: bytes("test data"),
            authData: AuthData({ redirectUrl: "https://example.com/redirect", issuedAt: uint64(block.timestamp) })
        });

        Payload.Call memory call = Payload.Call({
            to: makeAddr("target"),
            value: 1 ether,
            data: bytes("0x1234"),
            gasLimit: 100000,
            delegateCall: false,
            onlyFallback: false,
            behaviorOnError: Payload.BEHAVIOR_REVERT_ON_ERROR
        });

        bytes32 expectedResult = bytes32(uint256(3));
        vm.mockCall(
            _validator,
            abi.encodeWithSelector(
                IImplicitProjectValidation.validateAttestation.selector, wallet, attestation, _projectId
            ),
            abi.encode(expectedResult)
        );

        bytes32 result = _signals.acceptImplicitRequest(wallet, attestation, call);
        assertEq(result, expectedResult);
    }

    function testAcceptImplicitRequestWithDelegateCall() public {
        _signals.initialize(_owner, _validator, _projectId, false);

        address wallet = makeAddr("wallet");
        Attestation memory attestation = Attestation({
            approvedSigner: makeAddr("signer"),
            identityType: bytes4(0x12345678),
            issuerHash: bytes32(uint256(1)),
            audienceHash: bytes32(uint256(2)),
            applicationData: bytes("test data"),
            authData: AuthData({ redirectUrl: "https://example.com/redirect", issuedAt: uint64(block.timestamp) })
        });

        Payload.Call memory call = Payload.Call({
            to: makeAddr("target"),
            value: 0,
            data: bytes("0x1234"),
            gasLimit: 100000,
            delegateCall: true,
            onlyFallback: false,
            behaviorOnError: Payload.BEHAVIOR_IGNORE_ERROR
        });

        bytes32 expectedResult = bytes32(uint256(3));
        vm.mockCall(
            _validator,
            abi.encodeWithSelector(
                IImplicitProjectValidation.validateAttestation.selector, wallet, attestation, _projectId
            ),
            abi.encode(expectedResult)
        );

        bytes32 result = _signals.acceptImplicitRequest(wallet, attestation, call);
        assertEq(result, expectedResult);
    }

    function testAcceptImplicitRequestWithFallbackOnly() public {
        _signals.initialize(_owner, _validator, _projectId, false);

        address wallet = makeAddr("wallet");
        Attestation memory attestation = Attestation({
            approvedSigner: makeAddr("signer"),
            identityType: bytes4(0x12345678),
            issuerHash: bytes32(uint256(1)),
            audienceHash: bytes32(uint256(2)),
            applicationData: bytes("test data"),
            authData: AuthData({ redirectUrl: "https://example.com/redirect", issuedAt: uint64(block.timestamp) })
        });

        Payload.Call memory call = Payload.Call({
            to: makeAddr("target"),
            value: 0,
            data: bytes(""),
            gasLimit: 100000,
            delegateCall: false,
            onlyFallback: true,
            behaviorOnError: Payload.BEHAVIOR_ABORT_ON_ERROR
        });

        bytes32 expectedResult = bytes32(uint256(3));
        vm.mockCall(
            _validator,
            abi.encodeWithSelector(
                IImplicitProjectValidation.validateAttestation.selector, wallet, attestation, _projectId
            ),
            abi.encode(expectedResult)
        );

        bytes32 result = _signals.acceptImplicitRequest(wallet, attestation, call);
        assertEq(result, expectedResult);
    }

    function testAcceptImplicitRequestFailsWhenHookReverts() public {
        _signals.initialize(_owner, _validator, _projectId, true);

        address wallet = makeAddr("wallet");
        Attestation memory attestation = Attestation({
            approvedSigner: makeAddr("signer"),
            identityType: bytes4(0x12345678),
            issuerHash: bytes32(uint256(1)),
            audienceHash: bytes32(uint256(2)),
            applicationData: bytes("test data"),
            authData: AuthData({ redirectUrl: "https://example.com/redirect", issuedAt: uint64(block.timestamp) })
        });

        Payload.Call memory call = Payload.Call({
            to: makeAddr("target"),
            value: 0,
            data: bytes(""),
            gasLimit: 100000,
            delegateCall: false,
            onlyFallback: true,
            behaviorOnError: Payload.BEHAVIOR_ABORT_ON_ERROR
        });

        bytes32 expectedResult = bytes32(uint256(3));
        vm.mockCall(
            _validator,
            abi.encodeWithSelector(
                IImplicitProjectValidation.validateAttestation.selector, wallet, attestation, _projectId
            ),
            abi.encode(expectedResult)
        );

        vm.expectRevert("Hook reverted");
        _signals.acceptImplicitRequest(wallet, attestation, call);
    }

    function testAcceptImplicitRequestFailsWhenNotInitialized() public {
        address wallet = makeAddr("wallet");
        Attestation memory attestation = Attestation({
            approvedSigner: makeAddr("signer"),
            identityType: bytes4(0x12345678),
            issuerHash: bytes32(uint256(1)),
            audienceHash: bytes32(uint256(2)),
            applicationData: bytes("test data"),
            authData: AuthData({ redirectUrl: "https://example.com/redirect", issuedAt: uint64(block.timestamp) })
        });

        Payload.Call memory call = Payload.Call({
            to: address(0),
            value: 0,
            data: bytes(""),
            gasLimit: 0,
            delegateCall: false,
            onlyFallback: false,
            behaviorOnError: Payload.BEHAVIOR_REVERT_ON_ERROR
        });

        MockSignalsImplicitMode signals = new MockSignalsImplicitMode();
        vm.expectRevert();
        signals.acceptImplicitRequest(wallet, attestation, call);
    }

}

contract MockSignalsImplicitMode is SignalsImplicitModeControlled {

    bool private _hookReverts;

    function initialize(address owner, address validator, bytes32 projectId, bool hookReverts) external {
        _initializeImplicitMode(owner, validator, projectId);
        _hookReverts = hookReverts;
    }

    function _validateImplicitRequest(address, Attestation calldata, Payload.Call calldata) internal view override {
        if (_hookReverts) {
            revert("Hook reverted");
        }
    }

}
