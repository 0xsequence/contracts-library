// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { TestHelper } from "../../../../TestHelper.sol";
import { ERC20Mock } from "../../../../_mocks/ERC20Mock.sol";

import { IERC1155Supply, IERC1155SupplySignals } from "src/tokens/ERC1155/extensions/supply/IERC1155Supply.sol";
import { ERC1155Items } from "src/tokens/ERC1155/presets/items/ERC1155Items.sol";
import { ERC1155Sale, IERC1155Sale } from "src/tokens/ERC1155/utility/sale/ERC1155Sale.sol";
import { ERC1155SaleFactory } from "src/tokens/ERC1155/utility/sale/ERC1155SaleFactory.sol";

import { IAccessControl } from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";
import { IERC165 } from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

import { ISignalsImplicitMode } from "signals-implicit-mode/src/helper/SignalsImplicitMode.sol";

// solhint-disable not-rely-on-time

contract ERC1155SaleBaseTest is TestHelper, IERC1155SupplySignals {

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
        token.initialize(address(this), "test", "ipfs://", "ipfs://", address(this), 0, address(0), bytes32(0));

        sale = new ERC1155Sale();
        sale.initialize(address(this), address(token), address(0), bytes32(0));

        token.grantRole(keccak256("MINTER_ROLE"), address(sale));

        vm.deal(address(this), 1e6 ether);
    }

    function setUpFromFactory() public {
        ERC1155SaleFactory factory = new ERC1155SaleFactory(address(this));
        sale = ERC1155Sale(factory.deploy(0, proxyOwner, address(this), address(token), address(0), bytes32(0)));
        token.grantRole(keccak256("MINTER_ROLE"), address(sale));
    }

    function testSupportsInterface() public view {
        assertTrue(sale.supportsInterface(type(IERC165).interfaceId));
        assertTrue(sale.supportsInterface(type(IAccessControl).interfaceId));
        assertTrue(sale.supportsInterface(type(IERC1155Sale).interfaceId));
        assertTrue(sale.supportsInterface(type(ISignalsImplicitMode).interfaceId));
    }

    /**
     * Test all public selectors for collisions against the proxy admin functions.
     * @dev pnpm ts-node scripts/outputSelectors.ts
     */
    function testSelectorCollision() public pure {
        checkSelectorCollision(0xa217fddf); // DEFAULT_ADMIN_ROLE()
        checkSelectorCollision(0x9d043a66); // acceptImplicitRequest(address,(address,bytes4,bytes32,bytes32,bytes,(string,uint64)),(address,uint256,bytes,uint256,bool,bool,uint256))
        checkSelectorCollision(0x436013db); // addSaleDetails((uint256,uint256,uint256,address,uint256,uint64,uint64,bytes32))
        checkSelectorCollision(0xbad43661); // checkMerkleProof(bytes32,bytes32[],address,bytes32)
        checkSelectorCollision(0x248a9ca3); // getRoleAdmin(bytes32)
        checkSelectorCollision(0x9010d07c); // getRoleMember(bytes32,uint256)
        checkSelectorCollision(0xca15c873); // getRoleMemberCount(bytes32)
        checkSelectorCollision(0x2f2ff15d); // grantRole(bytes32,address)
        checkSelectorCollision(0x91d14854); // hasRole(bytes32,address)
        checkSelectorCollision(0x63acc14d); // initialize(address,address,address,bytes32)
        checkSelectorCollision(0xddced6e7); // mint(address,uint256[],uint256[],bytes,uint256[],address,uint256,bytes32[][])
        checkSelectorCollision(0x36568abe); // renounceRole(bytes32,address)
        checkSelectorCollision(0xd547741f); // revokeRole(bytes32,address)
        checkSelectorCollision(0x989d6ed1); // saleDetails(uint256)
        checkSelectorCollision(0xce6bcda7); // saleDetailsBatch(uint256[])
        checkSelectorCollision(0xfc640a87); // saleDetailsCount()
        checkSelectorCollision(0xed4c2ac7); // setImplicitModeProjectId(bytes32)
        checkSelectorCollision(0x0bb310de); // setImplicitModeValidator(address)
        checkSelectorCollision(0x01ffc9a7); // supportsInterface(bytes4)
        checkSelectorCollision(0x26f63107); // updateSaleDetails(uint256,(uint256,uint256,uint256,address,uint256,uint64,uint64,bytes32))
        checkSelectorCollision(0x44004cc1); // withdrawERC20(address,address,uint256)
        checkSelectorCollision(0x4782f779); // withdrawETH(address,uint256)
    }

    function testFactoryDetermineAddress(
        uint256 nonce,
        address _proxyOwner,
        address tokenOwner,
        address items,
        address implicitModeValidator,
        bytes32 implicitModeProjectId
    ) public {
        vm.assume(_proxyOwner != address(0));
        vm.assume(tokenOwner != address(0));
        ERC1155SaleFactory factory = new ERC1155SaleFactory(address(this));
        address deployedAddr =
            factory.deploy(nonce, _proxyOwner, tokenOwner, items, implicitModeValidator, implicitModeProjectId);
        address predictedAddr = factory.determineAddress(
            nonce, _proxyOwner, tokenOwner, items, implicitModeValidator, implicitModeProjectId
        );
        assertEq(deployedAddr, predictedAddr);
    }

    //
    // Admin
    //
    function test_addSaleDetails_success(
        IERC1155Sale.SaleDetails[] memory beforeDetails,
        IERC1155Sale.SaleDetails memory details
    ) public {
        for (uint256 i = 0; i < beforeDetails.length; i++) {
            sale.addSaleDetails(validSaleDetails(0, beforeDetails[i]));
        }

        details = validSaleDetails(0, details);
        vm.expectEmit(true, true, true, true);
        emit IERC1155Sale.SaleDetailsAdded(beforeDetails.length, details);
        uint256 saleIndex = sale.addSaleDetails(details);

        assertEq(sale.saleDetailsCount(), beforeDetails.length + 1);
        IERC1155Sale.SaleDetails memory actual = sale.saleDetails(saleIndex);
        _compareSaleDetails(actual, details);
    }

    function test_addSaleDetails_fail_invalidTokenId(
        IERC1155Sale.SaleDetails memory details
    ) public {
        details = validSaleDetails(0, details);
        details.minTokenId = bound(details.minTokenId, 1, type(uint256).max);
        details.maxTokenId = bound(details.maxTokenId, 0, details.minTokenId - 1);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Sale.InvalidSaleDetails.selector));
        sale.addSaleDetails(details);
    }

    function test_addSaleDetails_fail_invalidSupply(
        IERC1155Sale.SaleDetails memory details
    ) public {
        details = validSaleDetails(0, details);
        details.supply = 0;
        vm.expectRevert(abi.encodeWithSelector(IERC1155Sale.InvalidSaleDetails.selector));
        sale.addSaleDetails(details);
    }

    function test_addSaleDetails_fail_invalidStartTime(
        IERC1155Sale.SaleDetails memory details
    ) public {
        details = validSaleDetails(0, details);
        details.startTime = uint64(bound(details.startTime, 1, type(uint64).max));
        details.endTime = uint64(bound(details.endTime, 0, details.startTime - 1));
        vm.expectRevert(abi.encodeWithSelector(IERC1155Sale.InvalidSaleDetails.selector));
        sale.addSaleDetails(details);
    }

    function test_updateSaleDetails_success(
        IERC1155Sale.SaleDetails[] memory beforeDetails,
        IERC1155Sale.SaleDetails memory newDetails,
        uint256 saleIndex
    ) public {
        vm.assume(beforeDetails.length > 0);
        saleIndex = bound(saleIndex, 0, beforeDetails.length - 1);
        for (uint256 i = 0; i < beforeDetails.length; i++) {
            sale.addSaleDetails(validSaleDetails(0, beforeDetails[i]));
        }
        uint256 beforeUpdateCount = sale.saleDetailsCount();

        newDetails = validSaleDetails(0, newDetails);

        vm.expectEmit(true, true, true, true);
        emit IERC1155Sale.SaleDetailsUpdated(saleIndex, newDetails);
        sale.updateSaleDetails(saleIndex, newDetails);

        assertEq(sale.saleDetailsCount(), beforeUpdateCount); // Unchanged
        IERC1155Sale.SaleDetails memory actual = sale.saleDetails(saleIndex);
        _compareSaleDetails(actual, newDetails);
    }

    function test_updateSaleDetails_fail_notFound(
        IERC1155Sale.SaleDetails memory newDetails,
        uint256 saleIndex
    ) public {
        vm.assume(saleIndex >= sale.saleDetailsCount());
        vm.expectRevert(abi.encodeWithSelector(IERC1155Sale.SaleDetailsNotFound.selector, saleIndex));
        sale.updateSaleDetails(saleIndex, newDetails);
    }

    function test_updateSaleDetails_fail_invalidTokenId(
        IERC1155Sale.SaleDetails memory details
    ) public {
        details = validSaleDetails(0, details);
        uint256 saleIndex = sale.addSaleDetails(details);
        details.minTokenId = bound(details.minTokenId, 1, type(uint256).max);
        details.maxTokenId = bound(details.maxTokenId, 0, details.minTokenId - 1);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Sale.InvalidSaleDetails.selector));
        sale.updateSaleDetails(saleIndex, details);
    }

    function test_updateSaleDetails_fail_invalidSupply(
        IERC1155Sale.SaleDetails memory details
    ) public {
        details = validSaleDetails(0, details);
        uint256 saleIndex = sale.addSaleDetails(details);
        details.supply = 0;
        vm.expectRevert(abi.encodeWithSelector(IERC1155Sale.InvalidSaleDetails.selector));
        sale.updateSaleDetails(saleIndex, details);
    }

    function test_updateSaleDetails_fail_invalidStartTime(
        IERC1155Sale.SaleDetails memory details
    ) public {
        details = validSaleDetails(0, details);
        uint256 saleIndex = sale.addSaleDetails(details);
        details.startTime = uint64(bound(details.startTime, 1, type(uint64).max));
        details.endTime = uint64(bound(details.endTime, 0, details.startTime - 1));
        vm.expectRevert(abi.encodeWithSelector(IERC1155Sale.InvalidSaleDetails.selector));
        sale.updateSaleDetails(saleIndex, details);
    }

    function test_saleDetails_fail_notFound(
        uint256 saleIndex
    ) public {
        vm.assume(saleIndex >= sale.saleDetailsCount());
        vm.expectRevert(abi.encodeWithSelector(IERC1155Sale.SaleDetailsNotFound.selector, saleIndex));
        sale.saleDetails(saleIndex);
    }

    function test_saleDetailsBatch(
        IERC1155Sale.SaleDetails[] memory details
    ) public {
        uint256[] memory saleIndexes = new uint256[](details.length);
        for (uint256 i = 0; i < details.length; i++) {
            details[i] = validSaleDetails(0, details[i]);
            saleIndexes[i] = sale.addSaleDetails(details[i]);
        }
        assertEq(sale.saleDetailsCount(), details.length);
        IERC1155Sale.SaleDetails[] memory actual = sale.saleDetailsBatch(saleIndexes);
        assertEq(actual.length, details.length);
        for (uint256 i = 0; i < details.length; i++) {
            _compareSaleDetails(actual[i], details[i]);
        }
    }

    function test_saleDetailsBatch_fail_notFound(
        uint256[] memory saleIndexes
    ) public {
        vm.assume(saleIndexes.length > 0);
        vm.expectRevert(abi.encodeWithSelector(IERC1155Sale.SaleDetailsNotFound.selector, saleIndexes[0]));
        sale.saleDetailsBatch(saleIndexes);
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
        ERC20Mock erc20 = new ERC20Mock(address(this));
        erc20.mint(_sale, amount);

        uint256 saleBalance = erc20.balanceOf(_sale);
        uint256 balance = erc20.balanceOf(withdrawTo);
        sale.withdrawERC20(address(erc20), withdrawTo, saleBalance);
        assertEq(saleBalance + balance, erc20.balanceOf(withdrawTo));
        assertEq(0, erc20.balanceOf(_sale));
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

    function validSaleDetails(
        uint256 validTokenId,
        IERC1155Sale.SaleDetails memory saleDetails
    ) public view returns (IERC1155Sale.SaleDetails memory) {
        saleDetails.minTokenId = bound(saleDetails.minTokenId, 0, validTokenId);
        saleDetails.maxTokenId = bound(saleDetails.maxTokenId, validTokenId, type(uint256).max);
        saleDetails.supply = bound(saleDetails.supply, 1, type(uint256).max);
        saleDetails.cost = bound(saleDetails.cost, 0, type(uint256).max / saleDetails.supply);
        saleDetails.startTime = uint64(bound(saleDetails.startTime, 0, block.timestamp));
        saleDetails.endTime = uint64(bound(saleDetails.endTime, block.timestamp, type(uint64).max));
        saleDetails.paymentToken = address(0);
        saleDetails.merkleRoot = bytes32(0);
        return saleDetails;
    }

    function _compareSaleDetails(
        IERC1155Sale.SaleDetails memory actual,
        IERC1155Sale.SaleDetails memory expected
    ) internal pure {
        assertEq(actual.minTokenId, expected.minTokenId);
        assertEq(actual.maxTokenId, expected.maxTokenId);
        assertEq(actual.cost, expected.cost);
        assertEq(actual.paymentToken, expected.paymentToken);
        assertEq(actual.supply, expected.supply);
        assertEq(actual.startTime, expected.startTime);
        assertEq(actual.endTime, expected.endTime);
        assertEq(actual.merkleRoot, expected.merkleRoot);
    }

}
