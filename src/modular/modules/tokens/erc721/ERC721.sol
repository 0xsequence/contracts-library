// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { OwnablePrivate } from "../../ownable/OwnablePrivate.sol";
import { ERC721Storage } from "./ERC721Storage.sol";
import { ERC721 as SoladyERC721 } from "lib/solady/src/tokens/ERC721.sol";
import { LibString } from "lib/solady/src/utils/LibString.sol";

/// @title ERC721
/// @author Michael Standen
/// @notice ERC721 module
/// @dev Relies on the OwnablePrivate contract to manage ownership of the ERC721
contract ERC721 is SoladyERC721, OwnablePrivate {

    /// @notice Set the ERC721 metadata
    /// @param name_ The name of the ERC721
    /// @param symbol_ The symbol of the ERC721
    /// @param baseURI_ The base URI of the ERC721
    /// @param contractURI_ The contract URI of the ERC721
    function setMetadata(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        string memory contractURI_
    ) public onlyOwner {
        ERC721Storage.Metadata storage metadata = ERC721Storage.loadMetadata();
        metadata.name = name_;
        metadata.symbol = symbol_;
        metadata.baseURI = baseURI_;
        metadata.contractURI = contractURI_;
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
