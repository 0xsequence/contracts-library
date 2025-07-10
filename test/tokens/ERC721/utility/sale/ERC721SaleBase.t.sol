// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { TestHelper } from "../../../../TestHelper.sol";
import { ERC20Mock } from "../../../../_mocks/ERC20Mock.sol";

import { ERC721Items } from "src/tokens/ERC721/presets/items/ERC721Items.sol";
import { ERC721Sale } from "src/tokens/ERC721/utility/sale/ERC721Sale.sol";
import { ERC721SaleFactory } from "src/tokens/ERC721/utility/sale/ERC721SaleFactory.sol";
import { IERC721Sale, IERC721SaleFunctions, IERC721SaleSignals } from "src/tokens/ERC721/utility/sale/IERC721Sale.sol";

import { IAccessControl } from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { IERC721 } from "openzeppelin-contracts/contracts/interfaces/IERC721.sol";
import { IERC721Metadata } from "openzeppelin-contracts/contracts/interfaces/IERC721Metadata.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";
import { IERC165 } from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

import { ISignalsImplicitMode } from "signals-implicit-mode/src/helper/SignalsImplicitMode.sol";

// solhint-disable not-rely-on-time

contract ERC721SaleBaseTest is TestHelper, IERC721SaleSignals {

    // Redeclare events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    ERC721Items private token;
    ERC721Sale private sale;
    uint256 private perTokenCost = 0.02 ether;

    address private proxyOwner;

    function setUp() public {
        proxyOwner = makeAddr("proxyOwner");

        token = new ERC721Items();
        token.initialize(address(this), "test", "test", "ipfs://", "ipfs://", address(this), 0, address(0), bytes32(0));

        sale = new ERC721Sale();
        sale.initialize(address(this), address(token), address(0), bytes32(0));

        token.grantRole(keccak256("MINTER_ROLE"), address(sale));

        vm.deal(address(this), 100 ether);
    }

    function setUpFromFactory() public {
        ERC721SaleFactory factory = new ERC721SaleFactory(address(this));
        sale = ERC721Sale(factory.deploy(proxyOwner, address(this), address(token), address(0), bytes32(0)));
        token.grantRole(keccak256("MINTER_ROLE"), address(sale));
    }

    function testSupportsInterface() public view {
        assertTrue(sale.supportsInterface(type(IERC165).interfaceId));
        assertTrue(sale.supportsInterface(type(IAccessControl).interfaceId));
        assertTrue(sale.supportsInterface(type(IERC721SaleFunctions).interfaceId));
        assertTrue(sale.supportsInterface(type(ISignalsImplicitMode).interfaceId));
    }

    /**
     * Test all public selectors for collisions against the proxy admin functions.
     * @dev pnpm ts-node scripts/outputSelectors.ts
     */
    function testSelectorCollision() public pure {
        checkSelectorCollision(0xa217fddf); // DEFAULT_ADMIN_ROLE()
        checkSelectorCollision(0x9d043a66); // acceptImplicitRequest(address,(address,bytes4,bytes32,bytes32,bytes,(string,uint64)),(address,uint256,bytes,uint256,bool,bool,uint256))
        checkSelectorCollision(0xbad43661); // checkMerkleProof(bytes32,bytes32[],address,bytes32)
        checkSelectorCollision(0x248a9ca3); // getRoleAdmin(bytes32)
        checkSelectorCollision(0x9010d07c); // getRoleMember(bytes32,uint256)
        checkSelectorCollision(0xca15c873); // getRoleMemberCount(bytes32)
        checkSelectorCollision(0x2f2ff15d); // grantRole(bytes32,address)
        checkSelectorCollision(0x91d14854); // hasRole(bytes32,address)
        checkSelectorCollision(0x63acc14d); // initialize(address,address,address,bytes32)
        checkSelectorCollision(0xa971e842); // itemsContract()
        checkSelectorCollision(0x0668d0bb); // mint(address,uint256,address,uint256,bytes32[])
        checkSelectorCollision(0x36568abe); // renounceRole(bytes32,address)
        checkSelectorCollision(0xd547741f); // revokeRole(bytes32,address)
        checkSelectorCollision(0x3474a4a6); // saleDetails()
        checkSelectorCollision(0xed4c2ac7); // setImplicitModeProjectId(bytes32)
        checkSelectorCollision(0x0bb310de); // setImplicitModeValidator(address)
        checkSelectorCollision(0x8c17030f); // setSaleDetails(uint256,uint256,address,uint64,uint64,bytes32)
        checkSelectorCollision(0x01ffc9a7); // supportsInterface(bytes4)
        checkSelectorCollision(0x44004cc1); // withdrawERC20(address,address,uint256)
        checkSelectorCollision(0x4782f779); // withdrawETH(address,uint256)
    }

    function testFactoryDetermineAddress(
        address _proxyOwner,
        address tokenOwner,
        address items,
        address implicitModeValidator,
        bytes32 implicitModeProjectId
    ) public {
        vm.assume(_proxyOwner != address(0));
        vm.assume(tokenOwner != address(0));
        ERC721SaleFactory factory = new ERC721SaleFactory(address(this));
        address deployedAddr =
            factory.deploy(_proxyOwner, tokenOwner, items, implicitModeValidator, implicitModeProjectId);
        address predictedAddr =
            factory.determineAddress(_proxyOwner, tokenOwner, items, implicitModeValidator, implicitModeProjectId);
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

        ERC20Mock erc20 = new ERC20Mock(address(this));

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

        ERC20Mock erc20 = new ERC20Mock(address(this));
        erc20.mint(address(sale), amount);

        uint256 balance = erc20.balanceOf(withdrawTo);
        sale.withdrawERC20(address(erc20), withdrawTo, amount);
        assertEq(balance + amount, erc20.balanceOf(withdrawTo));
        assertEq(0, erc20.balanceOf(address(sale)));
    }

    //
    // Helpers
    //
    modifier withFactory(
        bool useFactory
    ) {
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
