// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { AccessControlEnumerable } from "openzeppelin-contracts/contracts/access/AccessControlEnumerable.sol";
import { IERC165, SignalsImplicitMode } from "signals-implicit-mode/src/helper/SignalsImplicitMode.sol";

/**
 * An abstract contract that allows implicit session access for a given project.
 */
abstract contract SignalsImplicitModeControlled is AccessControlEnumerable, SignalsImplicitMode {

    bytes32 internal constant _PROJECT_ADMIN_ROLE = keccak256("PROJECT_ADMIN_ROLE");

    function _initialize(
        address owner
    ) internal {
        _grantRole(_PROJECT_ADMIN_ROLE, owner);
    }

    /**
     * Updates the settings for implicit mode validation.
     * @param validator The validator address.
     * @param projectId The project id.
     * @notice Only callable by an address with the project admin role.
     */
    function setSignalsImplicitMode(address validator, bytes32 projectId) external onlyRole(_PROJECT_ADMIN_ROLE) {
        _initializeSignalsImplicitMode(validator, projectId);
    }

    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(AccessControlEnumerable, SignalsImplicitMode) returns (bool) {
        return
            AccessControlEnumerable.supportsInterface(interfaceId) || SignalsImplicitMode.supportsInterface(interfaceId);
    }

}
