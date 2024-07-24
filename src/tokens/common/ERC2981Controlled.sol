// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IERC2981Controlled} from "@0xsequence/contracts-library/tokens/common/IERC2981Controlled.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {AccessControlEnumerable} from "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

/**
 * An implementation of ERC-2981 that allows updates by roles.
 */
abstract contract ERC2981Controlled is ERC2981, AccessControlEnumerable, IERC2981Controlled {
    bytes32 internal constant ROYALTY_ADMIN_ROLE = keccak256("ROYALTY_ADMIN_ROLE");

    //
    // Royalty
    //

    /**
     * Sets the royalty information that all ids in this contract will default to.
     * @param receiver Address of who should be sent the royalty payment
     * @param feeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     */
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyRole(ROYALTY_ADMIN_ROLE) {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    /**
     * Sets the royalty information that a given token id in this contract will use.
     * @param tokenId The token id to set the royalty information for
     * @param receiver Address of who should be sent the royalty payment
     * @param feeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @notice This overrides the default royalty information for this token id
     */
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator)
        external
        onlyRole(ROYALTY_ADMIN_ROLE)
    {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    //
    // Views
    //

    /**
     * Check interface support.
     * @param interfaceId Interface id
     * @return True if supported
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC2981, AccessControlEnumerable)
        returns (bool)
    {
        return ERC2981.supportsInterface(interfaceId) || AccessControlEnumerable.supportsInterface(interfaceId)
            || type(IERC2981Controlled).interfaceId == interfaceId || super.supportsInterface(interfaceId);
    }
}
