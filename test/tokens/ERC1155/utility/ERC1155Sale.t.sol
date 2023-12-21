// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {stdError} from "forge-std/Test.sol";
import {TestHelper} from "../../../TestHelper.sol";

import {IERC1155SaleSignals, IERC1155SaleFunctions} from "src/tokens/ERC1155/utility/sale/IERC1155Sale.sol";
import {ERC1155Sale} from "src/tokens/ERC1155/utility/sale/ERC1155Sale.sol";
import {ERC1155SaleFactory} from "src/tokens/ERC1155/utility/sale/ERC1155SaleFactory.sol";
import {IERC1155SupplySignals, IERC1155Supply} from "src/tokens/ERC1155/extensions/supply/IERC1155Supply.sol";
import {ERC1155Items} from "src/tokens/ERC1155/presets/items/ERC1155Items.sol";

import {Merkle} from "murky/Merkle.sol";
import {ERC20Mock} from "@0xsequence/erc20-meta-token/contracts/mocks/ERC20Mock.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IMerkleProofSingleUseSignals} from "@0xsequence/contracts-library/tokens/common/IMerkleProofSingleUse.sol";

// Interfaces
import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {IERC1155Metadata} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155Metadata.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// solhint-disable not-rely-on-time

contract ERC1155SaleTest is TestHelper, Merkle, IERC1155SaleSignals, IERC1155SupplySignals, IMerkleProofSingleUseSignals {
    // Redeclare events
    event TransferSingle(
        address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _amount
    );
    event TransferBatch(
        address indexed _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _amounts
    );

    ERC1155Items private token;
    ERC1155Sale private sale;
    ERC20Mock private erc20;
    uint256 private perTokenCost = 0.02 ether;

    address private proxyOwner;

    address private constant ALLOWLIST_ADDR = 0xFA4eE536359087Fba7BD3248EE09e8Cc8347F8Ed;

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
        checkSelectorCollision(0xf8e4dec5); // checkMerkleProof(bytes32,bytes32[],address)
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
        checkSelectorCollision(0x43d3f88b); // setGlobalSaleDetails(uint256,uint256,address,uint64,uint64,bytes32)
        checkSelectorCollision(0x4f651ccd); // setTokenSaleDetails(uint256,uint256,uint256,uint64,uint64,bytes32)
        checkSelectorCollision(0x01ffc9a7); // supportsInterface(bytes4)
        checkSelectorCollision(0x0869678c); // tokenSaleDetails(uint256)
        checkSelectorCollision(0x44004cc1); // withdrawERC20(address,address,uint256)
        checkSelectorCollision(0x4782f779); // withdrawETH(address,uint256)
    }

    //
    // Minting
    //

    // Minting denied when no sale active.
    function testMintInactiveFail(bool useFactory, address mintTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(mintTo, tokenId, amount)
        withFactory(useFactory)
    {
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256 cost = amount * perTokenCost;

        vm.expectRevert(abi.encodeWithSelector(SaleInactive.selector, tokenId));
        sale.mint{value: cost}(mintTo, tokenIds, amounts, "", address(0), cost, TestHelper.blankProof());
    }

    // Minting denied when sale is active but not for the token.
    function testMintInactiveSingleFail(bool useFactory, address mintTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(mintTo, tokenId, amount)
        withFactory(useFactory)
        withTokenSaleActive(tokenId + 1)
    {
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256 cost = amount * perTokenCost;

        vm.expectRevert(abi.encodeWithSelector(SaleInactive.selector, tokenId));
        sale.mint{value: cost}(mintTo, tokenIds, amounts, "", address(0), cost, TestHelper.blankProof());
    }

    // Minting denied when token sale is expired.
    function testMintExpiredSingleFail(
        bool useFactory,
        address mintTo,
        uint256 tokenId,
        uint256 amount,
        uint64 startTime,
        uint64 endTime
    )
        public
        assumeSafe(mintTo, tokenId, amount)
        withFactory(useFactory)
    {
        if (startTime > endTime) {
            uint64 temp = startTime;
            startTime = endTime;
            endTime = temp;
        }
        if (block.timestamp >= startTime && block.timestamp <= endTime) {
            vm.warp(uint256(endTime) + 1);
        }
        sale.setTokenSaleDetails(tokenId, perTokenCost, 0, startTime, endTime, "");

        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256 cost = amount * perTokenCost;

        vm.expectRevert(abi.encodeWithSelector(SaleInactive.selector, tokenId));
        sale.mint{value: cost}(mintTo, tokenIds, amounts, "", address(0), cost, TestHelper.blankProof());
    }

    // Minting denied when global sale is expired.
    function testMintExpiredGlobalFail(
        bool useFactory,
        address mintTo,
        uint256 tokenId,
        uint256 amount,
        uint64 startTime,
        uint64 endTime
    )
        public
        assumeSafe(mintTo, tokenId, amount)
        withFactory(useFactory)
    {
        if (startTime > endTime) {
            uint64 temp = startTime;
            startTime = endTime;
            endTime = temp;
        }
        if (block.timestamp >= startTime && block.timestamp <= endTime) {
            vm.warp(uint256(endTime) + 1);
        }
        sale.setGlobalSaleDetails(perTokenCost, 0, address(0), startTime, endTime, "");

        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256 cost = amount * perTokenCost;

        vm.expectRevert(abi.encodeWithSelector(SaleInactive.selector, tokenId));
        sale.mint{value: cost}(mintTo, tokenIds, amounts, "", address(0), cost, TestHelper.blankProof());
    }

    // Minting denied when sale is active but not for all tokens in the group.
    function testMintInactiveInGroupFail(bool useFactory, address mintTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(mintTo, tokenId, amount)
        withFactory(useFactory)
        withTokenSaleActive(tokenId)
    {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId;
        tokenIds[1] = tokenId + 1;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount;
        uint256 cost = amount * perTokenCost * 2;

        vm.expectRevert(abi.encodeWithSelector(SaleInactive.selector, tokenId + 1));
        sale.mint{value: cost}(mintTo, tokenIds, amounts, "", address(0), cost, TestHelper.blankProof());
    }

    // Minting denied when global supply exceeded.
    function testMintGlobalSupplyExceeded(
        bool useFactory,
        address mintTo,
        uint256 tokenId,
        uint256 amount,
        uint256 supplyCap
    )
        public
        assumeSafe(mintTo, tokenId, amount)
        withFactory(useFactory)
    {
        if (supplyCap == 0 || supplyCap > 20) {
            supplyCap = 1;
        }
        if (amount <= supplyCap) {
            amount = supplyCap + 1;
        }
        sale.setGlobalSaleDetails(
            perTokenCost, supplyCap, address(0), uint64(block.timestamp), uint64(block.timestamp + 1), ""
        );

        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256 cost = amount * perTokenCost;

        vm.expectRevert(abi.encodeWithSelector(InsufficientSupply.selector, 0, amount, supplyCap));
        sale.mint{value: cost}(mintTo, tokenIds, amounts, "", address(0), cost, TestHelper.blankProof());
    }

    // Minting denied when token supply exceeded.
    function testMintTokenSupplyExceeded(
        bool useFactory,
        address mintTo,
        uint256 tokenId,
        uint256 amount,
        uint256 supplyCap
    )
        public
        assumeSafe(mintTo, tokenId, amount)
        withFactory(useFactory)
    {
        if (supplyCap == 0 || supplyCap > 20) {
            supplyCap = 1;
        }
        if (amount <= supplyCap) {
            amount = supplyCap + 1;
        }
        sale.setTokenSaleDetails(
            tokenId, perTokenCost, supplyCap, uint64(block.timestamp), uint64(block.timestamp + 1), ""
        );

        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256 cost = amount * perTokenCost;

        vm.expectRevert(abi.encodeWithSelector(InsufficientSupply.selector, 0, amount, supplyCap));
        sale.mint{value: cost}(mintTo, tokenIds, amounts, "", address(0), cost, TestHelper.blankProof());
    }

    // Minting allowed when sale is active globally.
    function testMintGlobalSuccess(bool useFactory, address mintTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(mintTo, tokenId, amount)
        withFactory(useFactory)
        withGlobalSaleActive
    {
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256 cost = amount * perTokenCost;

        uint256 count = token.balanceOf(mintTo, tokenId);
        vm.expectEmit(true, true, true, true, address(token));
        emit TransferBatch(address(sale), address(0), mintTo, tokenIds, amounts);
        sale.mint{value: cost}(mintTo, tokenIds, amounts, "", address(0), cost, TestHelper.blankProof());
        assertEq(count + amount, token.balanceOf(mintTo, tokenId));
    }

    // Minting allowed when sale is active for the token.
    function testMintSingleSuccess(bool useFactory, address mintTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(mintTo, tokenId, amount)
        withFactory(useFactory)
        withTokenSaleActive(tokenId)
    {
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256 cost = amount * perTokenCost;

        uint256 count = token.balanceOf(mintTo, tokenId);
        vm.expectEmit(true, true, true, true, address(token));
        emit TransferBatch(address(sale), address(0), mintTo, tokenIds, amounts);
        sale.mint{value: cost}(mintTo, tokenIds, amounts, "", address(0), cost, TestHelper.blankProof());
        assertEq(count + amount, token.balanceOf(mintTo, tokenId));
    }

    // Minting allowed when sale is active for both tokens individually.
    function testMintGroupSuccess(bool useFactory, address mintTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(mintTo, tokenId, amount)
        withFactory(useFactory)
    {
        setTokenSaleActive(tokenId);
        setTokenSaleActive(tokenId + 1);
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId;
        tokenIds[1] = tokenId + 1;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount;
        uint256 cost = amount * perTokenCost * 2;

        uint256 count = token.balanceOf(mintTo, tokenId);
        uint256 count2 = token.balanceOf(mintTo, tokenId + 1);
        vm.expectEmit(true, true, true, true, address(token));
        emit TransferBatch(address(sale), address(0), mintTo, tokenIds, amounts);
        sale.mint{value: cost}(mintTo, tokenIds, amounts, "", address(0), cost, TestHelper.blankProof());
        assertEq(count + amount, token.balanceOf(mintTo, tokenId));
        assertEq(count2 + amount, token.balanceOf(mintTo, tokenId + 1));
    }

    // Minting allowed when global sale is free.
    function testFreeGlobalMint(bool useFactory, address mintTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(mintTo, tokenId, amount)
        withFactory(useFactory)
    {
        sale.setGlobalSaleDetails(0, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), "");
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);

        uint256 count = token.balanceOf(mintTo, tokenId);
        vm.expectEmit(true, true, true, true, address(token));
        emit TransferBatch(address(sale), address(0), mintTo, tokenIds, amounts);
        sale.mint(mintTo, tokenIds, amounts, "", address(0), 0, TestHelper.blankProof());
        assertEq(count + amount, token.balanceOf(mintTo, tokenId));
    }

    // Minting allowed when token sale is free and global is not.
    function testFreeTokenMint(bool useFactory, address mintTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(mintTo, tokenId, amount)
        withFactory(useFactory)
        withGlobalSaleActive
    {
        sale.setTokenSaleDetails(tokenId, 0, 0, uint64(block.timestamp - 1), uint64(block.timestamp + 1), "");
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);

        uint256 count = token.balanceOf(mintTo, tokenId);
        vm.expectEmit(true, true, true, true, address(token));
        emit TransferBatch(address(sale), address(0), mintTo, tokenIds, amounts);
        sale.mint(mintTo, tokenIds, amounts, "", address(0), 0, TestHelper.blankProof());
        assertEq(count + amount, token.balanceOf(mintTo, tokenId));
    }

    // Minting allowed when mint charged with ERC20.
    function testERC20Mint(bool useFactory, address mintTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(mintTo, tokenId, amount)
        withFactory(useFactory)
        withERC20
    {
        sale.setGlobalSaleDetails(
            perTokenCost, 0, address(erc20), uint64(block.timestamp - 1), uint64(block.timestamp + 1), ""
        );
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256 cost = amount * perTokenCost;

        uint256 balance = erc20.balanceOf(address(this));
        uint256 count = token.balanceOf(mintTo, tokenId);
        vm.expectEmit(true, true, true, true, address(token));
        emit TransferBatch(address(sale), address(0), mintTo, tokenIds, amounts);
        sale.mint(mintTo, tokenIds, amounts, "", address(erc20), cost, TestHelper.blankProof());
        assertEq(count + amount, token.balanceOf(mintTo, tokenId));
        assertEq(balance - cost, erc20.balanceOf(address(this)));
        assertEq(cost, erc20.balanceOf(address(sale)));
    }

    // Minting with merkle success.
    function testMerkleSuccess(address[] memory allowlist, uint256 senderIndex, uint256 tokenId, bool globalActive)
        public
    {
        // Construct a merkle tree with the allowlist.
        vm.assume(allowlist.length > 1);
        vm.assume(senderIndex < allowlist.length);
        address sender = allowlist[senderIndex];
        vm.assume(sender != address(0));
        bytes32[] memory addrs = new bytes32[](allowlist.length);
        for (uint256 i = 0; i < allowlist.length; i++) {
            addrs[i] = keccak256(abi.encodePacked(allowlist[i]));
        }
        bytes32 root = getRoot(addrs);
        if (globalActive) {
            sale.setGlobalSaleDetails(0, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), root);
        } else {
            sale.setTokenSaleDetails(tokenId, 0, 0, uint64(block.timestamp - 1), uint64(block.timestamp + 1), root);
        }

        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(uint256(1));
        bytes32[] memory proof = getProof(addrs, senderIndex);

        vm.prank(sender);
        sale.mint(sender, tokenIds, amounts, "", address(0), 0, proof);

        assertEq(1, token.balanceOf(sender, tokenId));
    }

    // Minting with merkle reuse fail.
    function testMerkleReuseFail(address[] memory allowlist, uint256 senderIndex, uint256 tokenId, bool globalActive)
        public
    {
        // Copy of testMerkleSuccess
        vm.assume(allowlist.length > 1);
        vm.assume(senderIndex < allowlist.length);
        address sender = allowlist[senderIndex];
        vm.assume(sender != address(0));
        bytes32[] memory addrs = new bytes32[](allowlist.length);
        for (uint256 i = 0; i < allowlist.length; i++) {
            addrs[i] = keccak256(abi.encodePacked(allowlist[i]));
        }
        bytes32 root = getRoot(addrs);
        if (globalActive) {
            sale.setGlobalSaleDetails(0, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), root);
        } else {
            sale.setTokenSaleDetails(tokenId, 0, 0, uint64(block.timestamp - 1), uint64(block.timestamp + 1), root);
        }

        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(uint256(1));
        bytes32[] memory proof = getProof(addrs, senderIndex);

        vm.prank(sender);
        sale.mint(sender, tokenIds, amounts, "", address(0), 0, proof);

        assertEq(1, token.balanceOf(sender, tokenId));
        // End copy

        vm.expectRevert(abi.encodeWithSelector(MerkleProofInvalid.selector, root, proof, sender));
        vm.prank(sender);
        sale.mint(sender, tokenIds, amounts, "", address(0), 0, proof);
    }

    // Minting with merkle fail no proof.
    function testMerkleFailNoProof(address[] memory allowlist, address sender, uint256 tokenId, bool globalActive)
        public
    {
        // Construct a merkle tree with the allowlist.
        vm.assume(allowlist.length > 1);
        bytes32[] memory addrs = new bytes32[](allowlist.length);
        for (uint256 i = 0; i < allowlist.length; i++) {
            vm.assume(sender != allowlist[i]);
            addrs[i] = keccak256(abi.encodePacked(allowlist[i]));
        }
        bytes32 root = getRoot(addrs);
        if (globalActive) {
            sale.setGlobalSaleDetails(0, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), root);
        } else {
            sale.setTokenSaleDetails(tokenId, 0, 0, uint64(block.timestamp - 1), uint64(block.timestamp + 1), root);
        }

        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(uint256(1));
        bytes32[] memory proof = TestHelper.blankProof();

        vm.expectRevert(abi.encodeWithSelector(MerkleProofInvalid.selector, root, proof, sender));
        vm.prank(sender);
        sale.mint(sender, tokenIds, amounts, "", address(0), 0, TestHelper.blankProof());
    }

    // Minting with merkle fail bad proof.
    function testMerkleFailBadProof(address[] memory allowlist, address sender, uint256 tokenId, bool globalActive)
        public
    {
        // Construct a merkle tree with the allowlist.
        vm.assume(allowlist.length > 1);
        bytes32[] memory addrs = new bytes32[](allowlist.length);
        for (uint256 i = 0; i < allowlist.length; i++) {
            vm.assume(sender != allowlist[i]);
            addrs[i] = keccak256(abi.encodePacked(allowlist[i]));
        }
        bytes32 root = getRoot(addrs);
        if (globalActive) {
            sale.setGlobalSaleDetails(0, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), root);
        } else {
            sale.setTokenSaleDetails(tokenId, 0, 0, uint64(block.timestamp - 1), uint64(block.timestamp + 1), root);
        }

        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(uint256(1));
        bytes32[] memory proof = getProof(addrs, 1); // Wrong sender

        vm.expectRevert(abi.encodeWithSelector(MerkleProofInvalid.selector, root, proof, sender));
        vm.prank(sender);
        sale.mint(sender, tokenIds, amounts, "", address(0), 0, proof);
    }

    // Minting fails with invalid maxTotal.
    function testMintFailMaxTotal(bool useFactory, address mintTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(mintTo, tokenId, amount)
        withFactory(useFactory)
        withGlobalSaleActive
    {
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256 cost = amount * perTokenCost;

        bytes memory err = abi.encodeWithSelector(InsufficientPayment.selector, address(0), cost, cost - 1);

        vm.expectRevert(err);
        sale.mint{value: cost}(mintTo, tokenIds, amounts, "", address(0), cost - 1, TestHelper.blankProof());
    
        sale.setTokenSaleDetails(tokenId, perTokenCost, 0, uint64(block.timestamp - 1), uint64(block.timestamp + 1), "");
        vm.expectRevert(err);
        sale.mint{value: cost}(mintTo, tokenIds, amounts, "", address(0), cost - 1, TestHelper.blankProof());
        
        sale.setGlobalSaleDetails(
            perTokenCost, 0, address(erc20), uint64(block.timestamp - 1), uint64(block.timestamp + 1), ""
        );
        vm.expectRevert(err);
        sale.mint(mintTo, tokenIds, amounts, "", address(erc20), cost - 1, TestHelper.blankProof());
    }

    // Minting fails with invalid payment token.
    function testMintFailWrongPaymentToken(bool useFactory, address mintTo, uint256 tokenId, uint256 amount, address wrongToken)
        public
        assumeSafe(mintTo, tokenId, amount)
        withFactory(useFactory)
        withERC20
    {
        address paymentToken = wrongToken == address(0) ? address(erc20) : address(0);
        sale.setGlobalSaleDetails(
            0, 0, paymentToken, uint64(block.timestamp - 1), uint64(block.timestamp + 1), ""
        );
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);

        bytes memory err = abi.encodeWithSelector(InsufficientPayment.selector, paymentToken, 0, 0);
        vm.expectRevert(err);
        sale.mint(mintTo, tokenIds, amounts, "", wrongToken, 0, TestHelper.blankProof());
    
        sale.setTokenSaleDetails(tokenId, 0, 0, uint64(block.timestamp - 1), uint64(block.timestamp + 1), "");

        vm.expectRevert(err);
        sale.mint(mintTo, tokenIds, amounts, "", wrongToken, 0, TestHelper.blankProof());
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

        vm.expectRevert(revertString);
        sale.withdrawERC20(address(erc20), withdrawTo, amount);
    }

    // Withdraw success ETH
    function testWithdrawETH(bool useFactory, address withdrawTo, uint256 tokenId, uint256 amount)
        public
        withFactory(useFactory)
    {
        assumeSafeAddress(withdrawTo);
        testMintSingleSuccess(false, withdrawTo, tokenId, amount);

        uint256 saleBalance = address(sale).balance;
        uint256 balance = withdrawTo.balance;
        sale.withdrawETH(withdrawTo, saleBalance);
        assertEq(saleBalance + balance, withdrawTo.balance);
    }

    // Withdraw success ERC20
    function testWithdrawERC20(bool useFactory, address withdrawTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(withdrawTo, tokenId, amount)
        withFactory(useFactory)
    {
        testERC20Mint(false, withdrawTo, tokenId, amount);

        uint256 saleBalance = erc20.balanceOf(address(sale));
        uint256 balance = erc20.balanceOf(withdrawTo);
        sale.withdrawERC20(address(erc20), withdrawTo, saleBalance);
        assertEq(saleBalance + balance, erc20.balanceOf(withdrawTo));
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
        vm.assume(uint160(nonContract) > 16);
        vm.assume(nonContract != proxyOwner);
        vm.assume(nonContract.code.length == 0);
        vm.assume(tokenId < 100);
        vm.assume(amount > 0 && amount < 20);
        _;
    }

    // Create ERC20. Give this contract 1000 ERC20 tokens. Approve token to spend 100 ERC20 tokens.
    modifier withERC20() {
        erc20 = new ERC20Mock();
        erc20.mockMint(address(this), 1000 ether);
        erc20.approve(address(sale), 1000 ether);
        _;
    }

    modifier withGlobalSaleActive() {
        sale.setGlobalSaleDetails(
            perTokenCost, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), ""
        );
        _;
    }

    modifier withTokenSaleActive(uint256 tokenId) {
        setTokenSaleActive(tokenId);
        _;
    }

    function setTokenSaleActive(uint256 tokenId) private {
        sale.setTokenSaleDetails(tokenId, perTokenCost, 0, uint64(block.timestamp - 1), uint64(block.timestamp + 1), "");
    }
}
