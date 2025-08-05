// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { IModule } from "../../../../interfaces/IModule.sol";

interface IERC721Burn is IModule {

    /// @notice Burn a token
    /// @param tokenId The ID of the token to burn
    /// @dev The caller must be the owner of the token to burn
    function burn(
        uint256 tokenId
    ) external;

    /// @notice Burn a batch of tokens
    /// @param tokenIds The IDs of the tokens to burn
    /// @dev The caller must be the owner of the tokens to burn
    function batchBurn(
        uint256[] memory tokenIds
    ) external;

}
