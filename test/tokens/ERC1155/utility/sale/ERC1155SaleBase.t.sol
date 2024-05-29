// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {stdError} from "forge-std/Test.sol";
import {TestHelper} from "../../../../TestHelper.sol";

import {IERC1155SaleSignals, IERC1155SaleFunctions} from "src/tokens/ERC1155/utility/sale/IERC1155Sale.sol";
import {ERC1155Sale} from "src/tokens/ERC1155/utility/sale/ERC1155Sale.sol";
import {ERC1155SaleFactory} from "src/tokens/ERC1155/utility/sale/ERC1155SaleFactory.sol";
import {IERC1155SupplySignals, IERC1155Supply} from "src/tokens/ERC1155/extensions/supply/IERC1155Supply.sol";
import {ERC1155Items} from "src/tokens/ERC1155/presets/items/ERC1155Items.sol";

import {ERC20Mock} from "@0xsequence/erc20-meta-token/contracts/mocks/ERC20Mock.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// Interfaces
import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {IERC1155Metadata} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155Metadata.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// solhint-disable not-rely-on-time

contract ERC1155SaleTest is TestHelper, IERC1155SaleSignals, IERC1155SupplySignals {
    // Redeclare events
    event TransferSingle(
        address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _amount
    );
    event TransferBatch(
        address indexed _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _amounts
    );

    ERC1155Items private token;
    ERC1155Sale private sale;
    uint256 private perTokenCost = 0.02 ether;

    address private proxyOwner;

    function setUp() public {
        proxyOwner = makeAddr("proxyOwner");

        token = new ERC1155Items();
        token.initialize(address(this), "test", "ipfs://", "ipfs://", address(this), 0);

        sale = new ERC1155Sale();
        sale.initialize(address(this), address(token));

        token.grantRole(keccak256("MINTER_ROLE"), address(sale));

        vm.deal(address(this), 1e6 ether);
    }

    function setUpFromFactory() public {
        ERC1155SaleFactory factory = new ERC1155SaleFactory(address(this));
        sale = ERC1155Sale(factory.deploy(proxyOwner, address(this), address(token)));
        token.grantRole(keccak256("MINTER_ROLE"), address(sale));
    }

    function testSupportsInterface() public {
        assertTrue(sale.supportsInterface(type(IERC165).interfaceId));
        assertTrue(sale.supportsInterface(type(IAccessControl).interfaceId));
        assertTrue(sale.supportsInterface(type(IERC1155SaleFunctions).interfaceId));
    }

    /**
     * Test all public selectors for collisions against the proxy admin functions.
     * @dev yarn ts-node scripts/outputSelectors.ts
     */
    function testSelectorCollision() public {
        checkSelectorCollision(0xa217fddf); // DEFAULT_ADMIN_ROLE()
        checkSelectorCollision(0xbad43661); // checkMerkleProof(bytes32,bytes32[],address,bytes32)
        checkSelectorCollision(0x248a9ca3); // getRoleAdmin(bytes32)
        checkSelectorCollision(0x9010d07c); // getRoleMember(bytes32,uint256)
        checkSelectorCollision(0xca15c873); // getRoleMemberCount(bytes32)
        checkSelectorCollision(0x119cd50c); // globalSaleDetails()
        checkSelectorCollision(0x2f2ff15d); // grantRole(bytes32,address)
        checkSelectorCollision(0x91d14854); // hasRole(bytes32,address)
        checkSelectorCollision(0x485cc955); // initialize(address,address)
        checkSelectorCollision(0x60e606f6); // mint(address,uint256[],uint256[],bytes,address,uint256,bytes32[])
        checkSelectorCollision(0x3013ce29); // paymentToken()
        checkSelectorCollision(0x36568abe); // renounceRole(bytes32,address)
        checkSelectorCollision(0xd547741f); // revokeRole(bytes32,address)
        checkSelectorCollision(0x97559600); // setGlobalSaleDetails(uint256,uint256,uint64,uint64,bytes32)
        checkSelectorCollision(0x6a326ab1); // setPaymentToken(address)
        checkSelectorCollision(0x4f651ccd); // setTokenSaleDetails(uint256,uint256,uint256,uint64,uint64,bytes32)
        checkSelectorCollision(0x01ffc9a7); // supportsInterface(bytes4)
        checkSelectorCollision(0x0869678c); // tokenSaleDetails(uint256)
        checkSelectorCollision(0x44004cc1); // withdrawERC20(address,address,uint256)
        checkSelectorCollision(0x4782f779); // withdrawETH(address,uint256)
    }

    function testFactoryDetermineAddress(address _proxyOwner, address tokenOwner, address items) public {
        vm.assume(_proxyOwner != address(0));
        vm.assume(tokenOwner != address(0));
        ERC1155SaleFactory factory = new ERC1155SaleFactory(address(this));
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
        assumeSafeAddress(withdrawTo);

        address _sale = address(sale);
        vm.deal(_sale, amount);

        uint256 saleBalance = _sale.balance;
        uint256 balance = withdrawTo.balance;
        sale.withdrawETH(withdrawTo, saleBalance);

        assertEq(saleBalance + balance, withdrawTo.balance);
        assertEq(0, _sale.balance);
    }

    // Withdraw success ERC20
    function testWithdrawERC20(bool useFactory, address withdrawTo, uint256 amount) public withFactory(useFactory) {
        assumeSafeAddress(withdrawTo);

        address _sale = address(sale);
        ERC20Mock erc20 = new ERC20Mock();
        erc20.mockMint(_sale, amount);

        uint256 saleBalance = erc20.balanceOf(_sale);
        uint256 balance = erc20.balanceOf(withdrawTo);
        sale.withdrawERC20(address(erc20), withdrawTo, saleBalance);
        assertEq(saleBalance + balance, erc20.balanceOf(withdrawTo));
        assertEq(0, erc20.balanceOf(_sale));
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

    modifier assumeSafe(address nonContract, uint256 tokenId, uint256 amount) {
        assumeSafeAddress(nonContract);
        vm.assume(nonContract != proxyOwner);
        vm.assume(tokenId < 100);
        vm.assume(amount > 0 && amount < 20);
        _;
    }
}
