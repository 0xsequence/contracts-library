// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { AccessControlEnumerable } from "openzeppelin-contracts/contracts/access/AccessControlEnumerable.sol";
import {
    IERC165,
    IImplicitProjectValidation,
    SignalsImplicitMode
} from "signals-implicit-mode/src/helper/SignalsImplicitMode.sol";

/**
 * An abstract contract that allows implicit session access for a given project.
 */
abstract contract SignalsImplicitModeControlled is AccessControlEnumerable, SignalsImplicitMode {

    bytes32 internal constant _IMPLICIT_MODE_ADMIN_ROLE = keccak256("IMPLICIT_MODE_ADMIN_ROLE");

    function _initializeImplicitMode(address owner, address validator, bytes32 projectId) internal {
        _grantRole(_IMPLICIT_MODE_ADMIN_ROLE, owner);
        _initializeSignalsImplicitMode(validator, projectId);
    }

    /**
     * Updates the validator for implicit mode validation.
     * @param validator The validator address.
     * @notice Only callable by an address with the project admin role.
     */
    function setImplicitModeValidator(
        address validator
    ) external onlyRole(_IMPLICIT_MODE_ADMIN_ROLE) {
        _validator = IImplicitProjectValidation(validator);
    }

    /**
     * Updates the settings for implicit mode validation.
     * @param projectId The project id.
     * @notice Only callable by an address with the project admin role.
     */
    function setImplicitModeProjectId(
        bytes32 projectId
    ) external onlyRole(_IMPLICIT_MODE_ADMIN_ROLE) {
        _projectId = projectId;
    }

    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(AccessControlEnumerable, SignalsImplicitMode) returns (bool) {
        return
            AccessControlEnumerable.supportsInterface(interfaceId) || SignalsImplicitMode.supportsInterface(interfaceId);
    }

}
