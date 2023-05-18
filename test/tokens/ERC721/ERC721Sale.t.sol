// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {ERC721Sale} from "src/tokens/ERC721/ERC721Sale.sol";
import {ERC721SaleFactory} from "src/tokens/ERC721/ERC721SaleFactory.sol";
import {TWStrings} from "@thirdweb-dev/contracts/lib/TWStrings.sol";

contract ERC721SaleTest is Test {
    ERC721Sale private token;
    uint256 private perTokenCost = 0.02 ether;

    function setUp() public {
        vm.deal(address(this), 100 ether);

        ERC721SaleFactory factory = new ERC721SaleFactory();
        address[] memory _trustedFowarders = new address[](0);
        token = ERC721Sale(
            factory.deployERC721Sale(address(this), "test", "test", _trustedFowarders, address(this), address(this), 0, "")
        );
    }

    //
    // Admin Minting
    //
    function testAdminMintingSuccess(address receiver, uint256 amount) external assumeSafe(receiver, amount) {
        token.adminClaim(receiver, amount);

        assertEq(token.balanceOf(receiver), amount);
        assertEq(token.totalSupply(), amount);
    }

    function testAdminMintingNonAdmin(address receiver, uint256 amount) external assumeSafe(receiver, amount) {
        vm.expectRevert(
            abi.encodePacked(
                "Permissions: account ",
                TWStrings.toHexString(uint160(receiver), 20),
                " is missing role ",
                TWStrings.toHexString(uint256(0), 32)
            )
        );
        vm.prank(receiver);
        token.adminClaim(receiver, amount);
    }

    function testAdminMintMaxSupply(address receiver, uint256 amount) external assumeSafe(receiver, 1) {
        vm.assume(amount > 1);
        vm.assume(amount < type(uint128).max - 1);
        token.setMaxTotalSupply(amount - 1);
        vm.expectRevert("exceed max total supply.");
        token.adminClaim(receiver, amount);
    }

    //
    // Helpers
    //
    modifier assumeSafe(address nonContract, uint256 amount) {
        vm.assume(uint160(nonContract) > 16);
        vm.assume(nonContract.code.length == 0);
        vm.assume(amount > 0 && amount < 20);
        _;
    }
}
