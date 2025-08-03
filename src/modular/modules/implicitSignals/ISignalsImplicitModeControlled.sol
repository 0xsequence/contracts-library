// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

/// @title ISignalsImplicitModeControlled
/// @author Michael Standen
/// @notice Interface for the implicit mode controls
interface ISignalsImplicitModeControlled {

    /// @notice Sets the validator for implicit mode validation
    /// @param validator The validator address
    function setImplicitModeValidator(
        address validator
    ) external;

    /// @notice Sets the project id for implicit mode validation
    /// @param projectId The project id
    function setImplicitModeProjectId(
        bytes32 projectId
    ) external;

}
