// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {TestHelper} from "../../../../TestHelper.sol";

import {ERC721Sale} from "src/tokens/ERC721/utility/sale/ERC721Sale.sol";
import {IERC721SaleSignals, IERC721SaleFunctions, IERC721Sale} from "src/tokens/ERC721/utility/sale/IERC721Sale.sol";
import {ERC721SaleFactory} from "src/tokens/ERC721/utility/sale/ERC721SaleFactory.sol";
import {ERC721Items} from "src/tokens/ERC721/presets/items/ERC721Items.sol";

import {ERC20Mock} from "@0xsequence/erc20-meta-token/contracts/mocks/ERC20Mock.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// Interfaces
import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC721A} from "erc721a/contracts/interfaces/IERC721A.sol";
import {IERC721AQueryable} from "erc721a/contracts/interfaces/IERC721AQueryable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// solhint-disable not-rely-on-time

contract ERC721SaleTest is TestHelper, IERC721SaleSignals {
    // Redeclare events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    ERC721Items private token;
    ERC721Sale private sale;
    uint256 private perTokenCost = 0.02 ether;

    address private proxyOwner;

    function setUp() public {
        proxyOwner = makeAddr("proxyOwner");

        token = new ERC721Items();
        token.initialize(address(this), "test", "test", "ipfs://", "ipfs://", address(this), 0);

        sale = new ERC721Sale();
        sale.initialize(address(this), address(token));

        token.grantRole(keccak256("MINTER_ROLE"), address(sale));

        vm.deal(address(this), 100 ether);
    }

    function setUpFromFactory() public {
        ERC721SaleFactory factory = new ERC721SaleFactory(address(this));
        sale = ERC721Sale(factory.deploy(proxyOwner, address(this), address(token)));
        token.grantRole(keccak256("MINTER_ROLE"), address(sale));
    }

    function testSupportsInterface() public view {
        assertTrue(sale.supportsInterface(type(IERC165).interfaceId));
        assertTrue(sale.supportsInterface(type(IAccessControl).interfaceId));
        assertTrue(sale.supportsInterface(type(IERC721SaleFunctions).interfaceId));
    }

    /**
     * Test all public selectors for collisions against the proxy admin functions.
     * @dev yarn ts-node scripts/outputSelectors.ts
     */
    function testSelectorCollision() public pure {
        checkSelectorCollision(0xa217fddf); // DEFAULT_ADMIN_ROLE()
        checkSelectorCollision(0xbad43661); // checkMerkleProof(bytes32,bytes32[],address,bytes32)
        checkSelectorCollision(0x248a9ca3); // getRoleAdmin(bytes32)
        checkSelectorCollision(0x9010d07c); // getRoleMember(bytes32,uint256)
        checkSelectorCollision(0xca15c873); // getRoleMemberCount(bytes32)
        checkSelectorCollision(0x2f2ff15d); // grantRole(bytes32,address)
        checkSelectorCollision(0x91d14854); // hasRole(bytes32,address)
        checkSelectorCollision(0x485cc955); // initialize(address,address)
        checkSelectorCollision(0xa971e842); // itemsContract()
        checkSelectorCollision(0x0668d0bb); // mint(address,uint256,address,uint256,bytes32[])
        checkSelectorCollision(0x36568abe); // renounceRole(bytes32,address)
        checkSelectorCollision(0xd547741f); // revokeRole(bytes32,address)
        checkSelectorCollision(0x3474a4a6); // saleDetails()
        checkSelectorCollision(0x8c17030f); // setSaleDetails(uint256,uint256,address,uint64,uint64,bytes32)
        checkSelectorCollision(0x01ffc9a7); // supportsInterface(bytes4)
        checkSelectorCollision(0x44004cc1); // withdrawERC20(address,address,uint256)
        checkSelectorCollision(0x4782f779); // withdrawETH(address,uint256)
    }

    function testFactoryDetermineAddress(address _proxyOwner, address tokenOwner, address items) public {
        vm.assume(_proxyOwner != address(0));
        vm.assume(tokenOwner != address(0));
        ERC721SaleFactory factory = new ERC721SaleFactory(address(this));
        address deployedAddr = factory.deploy(_proxyOwner, tokenOwner, items);
        address predictedAddr = factory.determineAddress(_proxyOwner, tokenOwner, items);
        assertEq(deployedAddr, predictedAddr);
    }

    //
    // Withdraw
    //

    // Withdraw fails if the caller doesn't have the WITHDRAW_ROLE
    function testWithdrawFail(bool useFactory, address withdrawTo, uint256 amount) public withFactory(useFactory) {
        sale.revokeRole(keccak256("WITHDRAW_ROLE"), address(this));

        bytes memory revertString = abi.encodePacked(
            "AccessControl: account ",
            Strings.toHexString(address(this)),
            " is missing role ",
            vm.toString(keccak256("WITHDRAW_ROLE"))
        );

        vm.expectRevert(revertString);
        sale.withdrawETH(withdrawTo, amount);

        ERC20Mock erc20 = new ERC20Mock();

        vm.expectRevert(revertString);
        sale.withdrawERC20(address(erc20), withdrawTo, amount);
    }

    // Withdraw success ETH
    function testWithdrawETH(bool useFactory, address withdrawTo, uint256 amount) public withFactory(useFactory) {
        assumePayable(withdrawTo);
        vm.deal(address(sale), amount);

        uint256 saleBalance = address(sale).balance;
        uint256 balance = withdrawTo.balance;
        sale.withdrawETH(withdrawTo, saleBalance);
        assertEq(saleBalance + balance, withdrawTo.balance);
    }

    // Withdraw success ERC20
    function testWithdrawERC20(bool useFactory, address withdrawTo, uint256 amount) public withFactory(useFactory) {
        assumeSafeAddress(withdrawTo);

        ERC20Mock erc20 = new ERC20Mock();
        erc20.mockMint(address(sale), amount);

        uint256 balance = erc20.balanceOf(withdrawTo);
        sale.withdrawERC20(address(erc20), withdrawTo, amount);
        assertEq(balance + amount, erc20.balanceOf(withdrawTo));
        assertEq(0, erc20.balanceOf(address(sale)));
    }

    //
    // Helpers
    //
    modifier withFactory(bool useFactory) {
        if (useFactory) {
            setUpFromFactory();
        }
        _;
    }

    modifier assumeSafe(address nonContract, uint256 amount) {
        assumeSafeAddress(nonContract);
        vm.assume(amount > 0 && amount < 20);
        _;
    }
}
