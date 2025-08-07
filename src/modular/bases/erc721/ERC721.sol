// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { OwnableInternal } from "../../modules/ownable/OwnableInternal.sol";
import { ERC721Storage } from "./ERC721Storage.sol";
import { ERC721 as SoladyERC721 } from "lib/solady/src/tokens/ERC721.sol";
import { LibString } from "lib/solady/src/utils/LibString.sol";

/// @title ERC721
/// @author Michael Standen
/// @notice ERC721 module
/// @dev Relies on the Ownable module to manage ownership of the ERC721.
contract ERC721 is SoladyERC721, OwnableInternal {

    /// @notice Set the base metadata URI
    /// @param newBaseURI The base metadata URI
    function setBaseMetadataURI(
        string memory newBaseURI
    ) public onlyOwner {
        ERC721Storage.Metadata storage metadata = ERC721Storage.loadMetadata();
        metadata.baseURI = newBaseURI;
    }

    /// @notice Set the contract URI
    /// @param newContractURI The contract URI
    function setContractURI(
        string memory newContractURI
    ) public onlyOwner {
        ERC721Storage.Metadata storage metadata = ERC721Storage.loadMetadata();
        metadata.contractURI = newContractURI;
    }

    /// @notice Set the name and symbol
    /// @param newName The name
    /// @param newSymbol The symbol
    function setNameAndSymbol(string memory newName, string memory newSymbol) public onlyOwner {
        ERC721Storage.Metadata storage metadata = ERC721Storage.loadMetadata();
        metadata.name = newName;
        metadata.symbol = newSymbol;
    }

    /// @inheritdoc SoladyERC721
    function name() public view override returns (string memory) {
        return ERC721Storage.loadMetadata().name;
    }

    /// @inheritdoc SoladyERC721
    function symbol() public view override returns (string memory) {
        return ERC721Storage.loadMetadata().symbol;
    }

    /// @inheritdoc SoladyERC721
    function tokenURI(
        uint256 id
    ) public view override returns (string memory) {
        if (!_exists(id)) {
            revert TokenDoesNotExist();
        }

        string memory baseURI = ERC721Storage.loadMetadata().baseURI;
        return bytes(baseURI).length != 0 ? LibString.concat(baseURI, LibString.toString(id)) : "";
    }

    /// @notice Get the contract URI of token's URI.
    /// @return Contract URI of token's URI
    /// @dev Refer to https://docs.opensea.io/docs/contract-level-metadata
    function contractURI() public view returns (string memory) {
        return ERC721Storage.loadMetadata().contractURI;
    }

}
