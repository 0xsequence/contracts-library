// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * An implementation of ERC-2981 that allows updates by roles.
 */
abstract contract ERC2981Controlled is
    ERC2981,
    AccessControl
{
    bytes32 public constant ROYALTY_ADMIN_ROLE = keccak256("ROYALTY_ADMIN_ROLE");

    //
    // Royalty
    //

    /**
     * Sets the royalty information that all ids in this contract will default to.
     * @param _receiver Address of who should be sent the royalty payment
     * @param _feeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     */
    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) external onlyRole(ROYALTY_ADMIN_ROLE) {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    /**
     * Sets the royalty information that a given token id in this contract will use.
     * @param _tokenId The token id to set the royalty information for
     * @param _receiver Address of who should be sent the royalty payment
     * @param _feeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @notice This overrides the default royalty information for this token id
     */
    function setTokenRoyalty(uint256 _tokenId, address _receiver, uint96 _feeNumerator)
        external
        onlyRole(ROYALTY_ADMIN_ROLE)
    {
        _setTokenRoyalty(_tokenId, _receiver, _feeNumerator);
    }

    //
    // Views
    //

    /**
     * Check interface support.
     * @param _interfaceId Interface id
     * @return True if supported
     */
    function supportsInterface(bytes4 _interfaceId)
        public
        view
        virtual
        override (ERC2981, AccessControl)
        returns (bool)
    {
        return ERC2981.supportsInterface(_interfaceId) || AccessControl.supportsInterface(_interfaceId)
            || super.supportsInterface(_interfaceId);
    }
}
