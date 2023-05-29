// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {ERC1155Sale} from "src/tokens/ERC1155/ERC1155Sale.sol";
import {ERC1155SaleFactory} from "src/tokens/ERC1155/ERC1155SaleFactory.sol";
import {TWStrings} from "@thirdweb-dev/contracts/lib/TWStrings.sol";

contract ERC1155SaleTest is Test {
    ERC1155Sale private token;
    uint256 private perTokenCost = 0.02 ether;

    function setUp() public {
        vm.deal(address(this), 100 ether);

        ERC1155SaleFactory factory = new ERC1155SaleFactory();
        token = ERC1155Sale(
            factory.deployERC1155Sale(address(this), "_name", "_baseURI", address(this), address(this), 100, "")
        );
    }

    //
    // Admin Minting
    //
    function testAdminMintingSuccess(address receiver, uint256 tokenId, uint256 amount)
        external
        assumeSafe(receiver, tokenId, amount)
    {
        token.adminClaim(receiver, tokenId, amount);

        assertEq(token.balanceOf(receiver, tokenId), amount);
        // assertEq(token.totalSupply(tokenId), amount);
    }

    function testAdminMintingNonAdmin(address receiver, uint256 tokenId, uint256 amount)
        external
        assumeSafe(receiver, tokenId, amount)
    {
        vm.expectRevert(
            abi.encodePacked(
                "Permissions: account ",
                TWStrings.toHexString(uint160(receiver), 20),
                " is missing role ",
                TWStrings.toHexString(uint256(0), 32)
            )
        );
        vm.prank(receiver);
        token.adminClaim(receiver, tokenId, amount);
    }

    //
    // Helpers
    //
    modifier assumeSafe(address nonContract, uint256 tokenId, uint256 amount) {
        vm.assume(uint160(nonContract) > 16);
        vm.assume(nonContract.code.length == 0);
        vm.assume(tokenId < 100);
        vm.assume(amount > 0 && amount < 20);
        _;
    }
}
