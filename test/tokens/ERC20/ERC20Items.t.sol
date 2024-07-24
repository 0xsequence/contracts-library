// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {TestHelper} from "../../TestHelper.sol";

import {ERC20Items} from "src/tokens/ERC20/presets/items/ERC20Items.sol";
import {IERC20Items, IERC20ItemsSignals, IERC20ItemsFunctions} from "src/tokens/ERC20/presets/items/IERC20Items.sol";
import {ERC20ItemsFactory} from "src/tokens/ERC20/presets/items/ERC20ItemsFactory.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// Interfaces
import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract ERC20ItemsTest is TestHelper, IERC20ItemsSignals {
    // Redeclare events
    event Transfer(address indexed from, address indexed to, uint256 value);

    ERC20Items private token;

    uint8 private constant DECIMALS = 18;

    address private proxyOwner;
    address private owner; // Token owner

    function setUp() public {
        owner = makeAddr("owner");
        proxyOwner = makeAddr("proxyOwner");

        vm.deal(address(this), 100 ether);
        vm.deal(owner, 100 ether);

        ERC20ItemsFactory factory = new ERC20ItemsFactory(address(this));
        token = ERC20Items(factory.deploy(proxyOwner, owner, "name", "symbol", DECIMALS));
    }

    function testReinitializeFails() public {
        vm.expectRevert(InvalidInitialization.selector);
        token.initialize(owner, "name", "symbol", DECIMALS);
    }

    function testSupportsInterface() public view {
        assertTrue(token.supportsInterface(type(IERC165).interfaceId));
        assertTrue(token.supportsInterface(type(IERC20).interfaceId));
        assertTrue(token.supportsInterface(type(IERC20Metadata).interfaceId));
        assertTrue(token.supportsInterface(type(IERC20ItemsFunctions).interfaceId));
    }

    /**
     * Test all public selectors for collisions against the proxy admin functions.
     * @dev yarn ts-node scripts/outputSelectors.ts
     */
    function testSelectorCollision() public pure {
        checkSelectorCollision(0xa217fddf); // DEFAULT_ADMIN_ROLE()
        checkSelectorCollision(0xdd62ed3e); // allowance(address,address)
        checkSelectorCollision(0x095ea7b3); // approve(address,uint256)
        checkSelectorCollision(0x70a08231); // balanceOf(address)
        checkSelectorCollision(0x42966c68); // burn(uint256)
        checkSelectorCollision(0x313ce567); // decimals()
        checkSelectorCollision(0xa457c2d7); // decreaseAllowance(address,uint256)
        checkSelectorCollision(0x248a9ca3); // getRoleAdmin(bytes32)
        checkSelectorCollision(0x9010d07c); // getRoleMember(bytes32,uint256)
        checkSelectorCollision(0xca15c873); // getRoleMemberCount(bytes32)
        checkSelectorCollision(0x2f2ff15d); // grantRole(bytes32,address)
        checkSelectorCollision(0x91d14854); // hasRole(bytes32,address)
        checkSelectorCollision(0x39509351); // increaseAllowance(address,uint256)
        checkSelectorCollision(0xf6d2ee86); // initialize(address,string,string,uint8)
        checkSelectorCollision(0x40c10f19); // mint(address,uint256)
        checkSelectorCollision(0x06fdde03); // name()
        checkSelectorCollision(0x36568abe); // renounceRole(bytes32,address)
        checkSelectorCollision(0xd547741f); // revokeRole(bytes32,address)
        checkSelectorCollision(0x5a446215); // setNameAndSymbol(string,string)
        checkSelectorCollision(0x01ffc9a7); // supportsInterface(bytes4)
        checkSelectorCollision(0x95d89b41); // symbol()
        checkSelectorCollision(0x18160ddd); // totalSupply()
        checkSelectorCollision(0xa9059cbb); // transfer(address,uint256)
        checkSelectorCollision(0x23b872dd); // transferFrom(address,address,uint256)
    }

    function testOwnerHasRoles() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(token.hasRole(keccak256("MINTER_ROLE"), owner));
    }

    function testInitValues() public view {
        assertEq(token.name(), "name");
        assertEq(token.symbol(), "symbol");
        assertEq(token.decimals(), DECIMALS);
    }

    function testFactoryDetermineAddress(
        address _proxyOwner,
        address tokenOwner,
        string memory name,
        string memory symbol,
        uint8 decimals
    ) public {
        vm.assume(_proxyOwner != address(0));
        vm.assume(tokenOwner != address(0));
        ERC20ItemsFactory factory = new ERC20ItemsFactory(address(this));
        address deployedAddr = factory.deploy(_proxyOwner, tokenOwner, name, symbol, decimals);
        address predictedAddr = factory.determineAddress(_proxyOwner, tokenOwner, name, symbol, decimals);
        assertEq(deployedAddr, predictedAddr);
    }

    //
    // Minting
    //
    function testMintInvalidRole(address caller, uint256 amount) public {
        assumeSafeCaller(caller);
        vm.assume(amount > 0);

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(caller),
                " is missing role ",
                vm.toString(keccak256("MINTER_ROLE"))
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
        assumeSafeCaller(minter);
        vm.assume(amount > 0);

        // Give role
        vm.startPrank(owner);
        token.grantRole(keccak256("MINTER_ROLE"), minter);
        vm.stopPrank();

        vm.expectEmit(true, true, true, false, address(token));
        emit Transfer(address(0), owner, amount);

        vm.prank(minter);
        token.mint(owner, amount);

        assertEq(token.balanceOf(owner), amount);
    }

    //
    // Burn
    //
    function testBurnSuccess(address caller, uint256 amount, uint256 burnAmount) public {
        assumeSafeCaller(caller);
        vm.assume(amount >= burnAmount);
        vm.assume(amount > 0);

        vm.prank(owner);
        token.mint(caller, amount);

        vm.expectEmit(true, true, true, false, address(token));
        emit Transfer(caller, address(0), burnAmount);

        vm.prank(caller);
        token.burn(burnAmount);

        assertEq(token.balanceOf(caller), amount - burnAmount);
    }

    function testBurnInsufficient(address caller, uint256 amount, uint256 burnAmount) public {
        assumeSafeCaller(caller);
        vm.assume(burnAmount > amount);

        vm.prank(owner);
        token.mint(caller, amount);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        vm.prank(caller);
        token.burn(burnAmount);
    }

    //
    // Helpers
    //
    function assumeSafeCaller(address caller) private view {
        vm.assume(caller != owner);
        vm.assume(caller != proxyOwner);
        vm.assume(caller != address(0));
    }
}
