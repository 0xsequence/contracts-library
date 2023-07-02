// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {ERC20TokenMinter} from "src/tokens/ERC20/presets/minter/ERC20TokenMinter.sol";
import {IERC20TokenMinterSignals} from "src/tokens/ERC20/presets/minter/IERC20TokenMinter.sol";
import {ERC20TokenMinterFactory} from "src/tokens/ERC20/presets/minter/ERC20TokenMinterFactory.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// Interfaces
import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract ERC20TokenMinterTest is Test, IERC20TokenMinterSignals {
    // Redeclare events
    event Transfer(address indexed from, address indexed to, uint256 value);

    ERC20TokenMinter private token;

    uint8 private constant DECIMALS = 18;

    address owner;

    function setUp() public {
        owner = makeAddr("owner");

        vm.deal(address(this), 100 ether);
        vm.deal(owner, 100 ether);

        ERC20TokenMinterFactory factory = new ERC20TokenMinterFactory();
        token = ERC20TokenMinter(factory.deploy(owner, "name", "symbol", DECIMALS, 0x0));
    }

    function testReinitializeFails() public {
        vm.expectRevert(InvalidInitialization.selector);
        token.initialize(owner, "name", "symbol", DECIMALS);
    }

    function testSupportsInterface() public {
        assertTrue(token.supportsInterface(type(IERC165).interfaceId));
        assertTrue(token.supportsInterface(type(IERC20).interfaceId));
        assertTrue(token.supportsInterface(type(IERC20Metadata).interfaceId));
    }

    function testOwnerHasRoles() public {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(token.hasRole(token.MINTER_ROLE(), owner));
    }

    function testInitValues() public {
        assertEq(token.name(), "name");
        assertEq(token.symbol(), "symbol");
        assertEq(token.decimals(), DECIMALS);
    }

    //
    // Minting
    //
    function testMintInvalidRole(address caller, uint256 amount) public {
        vm.assume(caller != owner);
        vm.assume(amount > 0);

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(caller),
                " is missing role ",
                Strings.toHexString(uint256(token.MINTER_ROLE()), 32)
            )
        );
        vm.prank(caller);
        token.mint(caller, amount);
    }

    function testMintOwner(uint256 amount) public {
        vm.assume(amount > 0);

        vm.expectEmit(true, true, true, false, address(token));
        emit Transfer(address(0), owner, amount);

        vm.prank(owner);
        token.mint(owner, amount);

        assertEq(token.balanceOf(owner), amount);
    }

    function testMintWithRole(address minter, uint256 amount) public {
        vm.assume(minter != owner);
        vm.assume(minter != address(0));
        vm.assume(amount > 0);
        // Give role
        vm.startPrank(owner);
        token.grantRole(token.MINTER_ROLE(), minter);
        vm.stopPrank();

        vm.expectEmit(true, true, true, false, address(token));
        emit Transfer(address(0), owner, amount);

        vm.prank(minter);
        token.mint(owner, amount);

        assertEq(token.balanceOf(owner), amount);
    }
}
