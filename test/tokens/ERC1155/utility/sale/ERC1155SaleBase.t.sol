// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { TestHelper } from "../../../../TestHelper.sol";
import { ERC20Mock } from "../../../../_mocks/ERC20Mock.sol";

import { IERC1155Supply, IERC1155SupplySignals } from "src/tokens/ERC1155/extensions/supply/IERC1155Supply.sol";
import { ERC1155Items } from "src/tokens/ERC1155/presets/items/ERC1155Items.sol";
import { ERC1155Sale } from "src/tokens/ERC1155/utility/sale/ERC1155Sale.sol";
import { ERC1155SaleFactory } from "src/tokens/ERC1155/utility/sale/ERC1155SaleFactory.sol";
import { IERC1155SaleFunctions, IERC1155SaleSignals } from "src/tokens/ERC1155/utility/sale/IERC1155Sale.sol";

import { IAccessControl } from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import { Strings } from "openzeppelin-contracts/contracts/utils/Strings.sol";
import { IERC165 } from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

import { ISignalsImplicitMode } from "signals-implicit-mode/src/helper/SignalsImplicitMode.sol";

// solhint-disable not-rely-on-time

contract ERC1155SaleBaseTest is TestHelper, IERC1155SaleSignals, IERC1155SupplySignals {

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
        assertTrue(sale.supportsInterface(type(IERC1155SaleFunctions).interfaceId));
        assertTrue(sale.supportsInterface(type(ISignalsImplicitMode).interfaceId));
    }

    /**
     * Test all public selectors for collisions against the proxy admin functions.
     * @dev yarn ts-node scripts/outputSelectors.ts
     */
    function testSelectorCollision() public pure {
        checkSelectorCollision(0xa217fddf); // DEFAULT_ADMIN_ROLE()
        checkSelectorCollision(0x9d043a66); // acceptImplicitRequest(address,(address,bytes4,bytes32,bytes32,bytes,(string,uint64)),(address,uint256,bytes,uint256,bool,bool,uint256))
        checkSelectorCollision(0xbad43661); // checkMerkleProof(bytes32,bytes32[],address,bytes32)
        checkSelectorCollision(0x248a9ca3); // getRoleAdmin(bytes32)
        checkSelectorCollision(0x9010d07c); // getRoleMember(bytes32,uint256)
        checkSelectorCollision(0xca15c873); // getRoleMemberCount(bytes32)
        checkSelectorCollision(0x119cd50c); // globalSaleDetails()
        checkSelectorCollision(0x2f2ff15d); // grantRole(bytes32,address)
        checkSelectorCollision(0x91d14854); // hasRole(bytes32,address)
        checkSelectorCollision(0x63acc14d); // initialize(address,address,address,bytes32)
        checkSelectorCollision(0x60e606f6); // mint(address,uint256[],uint256[],bytes,address,uint256,bytes32[])
        checkSelectorCollision(0x3013ce29); // paymentToken()
        checkSelectorCollision(0x36568abe); // renounceRole(bytes32,address)
        checkSelectorCollision(0xd547741f); // revokeRole(bytes32,address)
        checkSelectorCollision(0x97559600); // setGlobalSaleDetails(uint256,uint256,uint64,uint64,bytes32)
        checkSelectorCollision(0xed4c2ac7); // setImplicitModeProjectId(bytes32)
        checkSelectorCollision(0x0bb310de); // setImplicitModeValidator(address)
        checkSelectorCollision(0x6a326ab1); // setPaymentToken(address)
        checkSelectorCollision(0x4f651ccd); // setTokenSaleDetails(uint256,uint256,uint256,uint64,uint64,bytes32)
        checkSelectorCollision(0xf07f04ff); // setTokenSaleDetailsBatch(uint256[],uint256[],uint256[],uint64[],uint64[],bytes32[])
        checkSelectorCollision(0x01ffc9a7); // supportsInterface(bytes4)
        checkSelectorCollision(0x0869678c); // tokenSaleDetails(uint256)
        checkSelectorCollision(0xff81434e); // tokenSaleDetailsBatch(uint256[])
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
    // Setter and getter
    //
    function testGlobalSaleDetails(
        uint256 minTokenId,
        uint256 maxTokenId,
        uint256 cost,
        uint256 remainingSupply,
        uint64 startTime,
        uint64 endTime,
        bytes32 merkleRoot
    ) public {
        remainingSupply = bound(remainingSupply, 1, type(uint256).max);
        endTime = uint64(bound(endTime, block.timestamp + 1, type(uint64).max));
        startTime = uint64(bound(startTime, 0, endTime));

        // Setter
        vm.expectEmit(true, true, true, true, address(sale));
        emit GlobalSaleDetailsUpdated(minTokenId, maxTokenId, cost, remainingSupply, startTime, endTime, merkleRoot);
        sale.setGlobalSaleDetails(minTokenId, maxTokenId, cost, remainingSupply, startTime, endTime, merkleRoot);

        // Getter
        IERC1155SaleFunctions.GlobalSaleDetails memory _saleDetails = sale.globalSaleDetails();
        assertEq(minTokenId, _saleDetails.minTokenId);
        assertEq(maxTokenId, _saleDetails.maxTokenId);
        assertEq(cost, _saleDetails.cost);
        assertEq(remainingSupply, _saleDetails.remainingSupply);
        assertEq(startTime, _saleDetails.startTime);
        assertEq(endTime, _saleDetails.endTime);
        assertEq(merkleRoot, _saleDetails.merkleRoot);
    }

    function testTokenSaleDetails(
        uint256 tokenId,
        uint256 cost,
        uint256 remainingSupply,
        uint64 startTime,
        uint64 endTime,
        bytes32 merkleRoot
    ) public {
        remainingSupply = bound(remainingSupply, 1, type(uint256).max);
        endTime = uint64(bound(endTime, block.timestamp + 1, type(uint64).max));
        startTime = uint64(bound(startTime, 0, endTime));

        // Setter
        vm.expectEmit(true, true, true, true, address(sale));
        emit TokenSaleDetailsUpdated(tokenId, cost, remainingSupply, startTime, endTime, merkleRoot);
        sale.setTokenSaleDetails(tokenId, cost, remainingSupply, startTime, endTime, merkleRoot);

        // Getter
        IERC1155SaleFunctions.SaleDetails memory _saleDetails = sale.tokenSaleDetails(tokenId);
        assertEq(cost, _saleDetails.cost);
        assertEq(remainingSupply, _saleDetails.remainingSupply);
        assertEq(startTime, _saleDetails.startTime);
        assertEq(endTime, _saleDetails.endTime);
        assertEq(merkleRoot, _saleDetails.merkleRoot);
    }

    function testTokenSaleDetailsBatch(
        uint256[] memory tokenIds,
        uint256[] memory costs,
        uint256[] memory remainingSupplys,
        uint64[] memory startTimes,
        uint64[] memory endTimes,
        bytes32[] memory merkleRoots
    ) public {
        uint256 minLength = tokenIds.length;
        minLength = minLength > costs.length ? costs.length : minLength;
        minLength = minLength > remainingSupplys.length ? remainingSupplys.length : minLength;
        minLength = minLength > startTimes.length ? startTimes.length : minLength;
        minLength = minLength > endTimes.length ? endTimes.length : minLength;
        minLength = minLength > merkleRoots.length ? merkleRoots.length : minLength;
        minLength = minLength > 5 ? 5 : minLength; // Max 5
        vm.assume(minLength > 0);
        // solhint-disable-next-line no-inline-assembly
        assembly {
            mstore(tokenIds, minLength)
            mstore(costs, minLength)
            mstore(remainingSupplys, minLength)
            mstore(startTimes, minLength)
            mstore(endTimes, minLength)
            mstore(merkleRoots, minLength)
        }

        // Sort tokenIds ascending and ensure no duplicates
        for (uint256 i = 0; i < minLength; i++) {
            for (uint256 j = i + 1; j < minLength; j++) {
                if (tokenIds[i] > tokenIds[j]) {
                    (tokenIds[i], tokenIds[j]) = (tokenIds[j], tokenIds[i]);
                }
            }
        }
        for (uint256 i = 0; i < minLength - 1; i++) {
            vm.assume(tokenIds[i] != tokenIds[i + 1]);
        }

        // Bound values
        for (uint256 i = 0; i < minLength; i++) {
            remainingSupplys[i] = bound(remainingSupplys[i], 1, type(uint256).max);
            endTimes[i] = uint64(bound(endTimes[i], block.timestamp + 1, type(uint64).max));
            startTimes[i] = uint64(bound(startTimes[i], 0, endTimes[i]));
        }

        // Setter
        for (uint256 i = 0; i < minLength; i++) {
            vm.expectEmit(true, true, true, true, address(sale));
            emit TokenSaleDetailsUpdated(
                tokenIds[i], costs[i], remainingSupplys[i], startTimes[i], endTimes[i], merkleRoots[i]
            );
        }
        sale.setTokenSaleDetailsBatch(tokenIds, costs, remainingSupplys, startTimes, endTimes, merkleRoots);

        // Getter
        IERC1155SaleFunctions.SaleDetails[] memory _saleDetails = sale.tokenSaleDetailsBatch(tokenIds);
        for (uint256 i = 0; i < minLength; i++) {
            assertEq(costs[i], _saleDetails[i].cost);
            assertEq(remainingSupplys[i], _saleDetails[i].remainingSupply);
            assertEq(startTimes[i], _saleDetails[i].startTime);
            assertEq(endTimes[i], _saleDetails[i].endTime);
            assertEq(merkleRoots[i], _saleDetails[i].merkleRoot);
        }
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

    modifier assumeSafe(address nonContract, uint256 tokenId, uint256 amount) {
        assumeSafeAddress(nonContract);
        vm.assume(nonContract != proxyOwner);
        vm.assume(tokenId < 100);
        vm.assume(amount > 0 && amount < 20);
        _;
    }

}
