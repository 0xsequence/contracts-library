// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {IGenericToken} from "./IGenericToken.sol";
import {ERC721BaseToken} from "src/tokens/ERC721/ERC721BaseToken.sol";

contract ERC721Mock is ERC721BaseToken, IGenericToken {
    constructor(address owner, string memory tokenBaseURI) {
        _initialize(owner, "", "", tokenBaseURI, "");
    }

    function _sequentialUpTo() internal pure override returns (uint256) {
        // Force non sequential minting
        return 0;
    }

    function mint(address to, uint256 tokenId, uint256) external override {
        _mintSpot(to, tokenId);
    }

    function approve(address, address operator, uint256 tokenId, uint256) external override {
        _approve(operator, tokenId, false);
    }

    function balanceOf(address owner, uint256 tokenId) external view override returns (uint256) {
        try this.ownerOf(tokenId) returns (address ownerOfToken) {
            return ownerOfToken == owner ? 1 : 0;
        } catch {
            return 0;
        }
    }
}
