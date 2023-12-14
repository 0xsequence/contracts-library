// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {TestHelper} from "../../../TestHelper.sol";

import {ERC721Sale} from "src/tokens/ERC721/utility/sale/ERC721Sale.sol";
import {IERC721SaleSignals, IERC721SaleFunctions, IERC721Sale} from "src/tokens/ERC721/utility/sale/IERC721Sale.sol";
import {ERC721SaleFactory} from "src/tokens/ERC721/utility/sale/ERC721SaleFactory.sol";
import {ERC721Items} from "src/tokens/ERC721/presets/items/ERC721Items.sol";

import {Merkle} from "murky/Merkle.sol";
import {ERC20Mock} from "@0xsequence/erc20-meta-token/contracts/mocks/ERC20Mock.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IMerkleProofSingleUseSignals} from "@0xsequence/contracts-library/tokens/common/IMerkleProofSingleUse.sol";

// Interfaces
import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Metadata} from "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import {IERC721A} from "erc721a/contracts/interfaces/IERC721A.sol";
import {IERC721AQueryable} from "erc721a/contracts/interfaces/IERC721AQueryable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// solhint-disable not-rely-on-time

contract ERC721SaleTest is TestHelper, Merkle, IERC721SaleSignals, IMerkleProofSingleUseSignals {
    // Redeclare events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    ERC721Items private token;
    ERC721Sale private sale;
    ERC20Mock private erc20;
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

    function testSupportsInterface() public {
        assertTrue(sale.supportsInterface(type(IERC165).interfaceId));
        assertTrue(sale.supportsInterface(type(IAccessControl).interfaceId));
        assertTrue(sale.supportsInterface(type(IERC721SaleFunctions).interfaceId));
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
        checkSelectorCollision(0x2f2ff15d); // grantRole(bytes32,address)
        checkSelectorCollision(0x91d14854); // hasRole(bytes32,address)
        checkSelectorCollision(0x485cc955); // initialize(address,address)
        checkSelectorCollision(0xa971e842); // itemsContract()
        checkSelectorCollision(0x641ce140); // mint(address,uint256,bytes32[])
        checkSelectorCollision(0x36568abe); // renounceRole(bytes32,address)
        checkSelectorCollision(0xd547741f); // revokeRole(bytes32,address)
        checkSelectorCollision(0x3474a4a6); // saleDetails()
        checkSelectorCollision(0x8c17030f); // setSaleDetails(uint256,uint256,address,uint64,uint64,bytes32)
        checkSelectorCollision(0x01ffc9a7); // supportsInterface(bytes4)
        checkSelectorCollision(0x44004cc1); // withdrawERC20(address,address,uint256)
        checkSelectorCollision(0x4782f779); // withdrawETH(address,uint256)
    }

    //
    // Minting
    //

    // Minting denied when no sale active.
    function testMintInactiveFail(bool useFactory, address mintTo, uint256 amount)
        public
        assumeSafe(mintTo, amount)
        withFactory(useFactory)
    {
        vm.expectRevert(SaleInactive.selector);
        sale.mint{value: amount * perTokenCost}(mintTo, amount, TestHelper.blankProof());
    }

    // Minting denied when sale is expired.
    function testMintExpiredFail(bool useFactory, address mintTo, uint256 amount, uint64 startTime, uint64 endTime)
        public
        assumeSafe(mintTo, amount)
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
        sale.setSaleDetails(0, perTokenCost, address(0), uint64(startTime), uint64(endTime), "");

        vm.expectRevert(SaleInactive.selector);
        sale.mint{value: amount * perTokenCost}(mintTo, amount, TestHelper.blankProof());
    }

    // Minting denied when supply exceeded.
    function testMintSupplyExceeded(bool useFactory, address mintTo, uint256 amount, uint256 supplyCap)
        public
        assumeSafe(mintTo, amount)
        withFactory(useFactory)
    {
        if (supplyCap == 0 || supplyCap > 20) {
            supplyCap = 1;
        }
        if (amount <= supplyCap) {
            amount = supplyCap + 1;
        }
        sale.setSaleDetails(
            supplyCap, perTokenCost, address(0), uint64(block.timestamp), uint64(block.timestamp + 1), ""
        );

        vm.expectRevert(abi.encodeWithSelector(InsufficientSupply.selector, 0, amount, supplyCap));
        sale.mint{value: amount * perTokenCost}(mintTo, amount, TestHelper.blankProof());
    }

    // Minting allowed when sale is active.
    function testMintSuccess(bool useFactory, address mintTo, uint256 amount)
        public
        assumeSafe(mintTo, amount)
        withFactory(useFactory)
        withSaleActive
    {
        uint256 count = token.balanceOf(mintTo);
        vm.expectEmit(true, true, true, true, address(token));
        emit Transfer(address(0), mintTo, 0);
        sale.mint{value: amount * perTokenCost}(mintTo, amount, TestHelper.blankProof());
        assertEq(count + amount, token.balanceOf(mintTo));
    }

    // Minting allowed when sale is free.
    function testFreeMint(bool useFactory, address mintTo, uint256 amount)
        public
        assumeSafe(mintTo, amount)
        withFactory(useFactory)
    {
        sale.setSaleDetails(0, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), "");

        uint256 count = token.balanceOf(mintTo);
        vm.expectEmit(true, true, true, true, address(token));
        emit Transfer(address(0), mintTo, 0);
        sale.mint(mintTo, amount, TestHelper.blankProof());
        assertEq(count + amount, token.balanceOf(mintTo));
    }

    // Minting allowed when mint charged with ERC20.
    function testERC20Mint(bool useFactory, address mintTo, uint256 amount)
        public
        assumeSafe(mintTo, amount)
        withFactory(useFactory)
        withERC20
    {
        sale.setSaleDetails(
            0, perTokenCost, address(erc20), uint64(block.timestamp - 1), uint64(block.timestamp + 1), ""
        );
        uint256 cost = amount * perTokenCost;

        uint256 balanace = erc20.balanceOf(address(this));
        uint256 count = token.balanceOf(mintTo);
        vm.expectEmit(true, true, true, true, address(token));
        emit Transfer(address(0), mintTo, 0);
        sale.mint(mintTo, amount, TestHelper.blankProof());
        assertEq(count + amount, token.balanceOf(mintTo));
        assertEq(balanace - cost, erc20.balanceOf(address(this)));
        assertEq(cost, erc20.balanceOf(address(sale)));
    }

    // Minting with merkle success.
    function testMerkleSuccess(address[] memory allowlist, uint256 senderIndex) public {
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
        sale.setSaleDetails(0, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), root);

        bytes32[] memory proof = getProof(addrs, senderIndex);

        vm.prank(sender);
        sale.mint(sender, 1, proof);

        assertEq(1, token.balanceOf(sender));
    }

    // Minting with merkle reuse fail.
    function testMerkleReuseFail(address[] memory allowlist, uint256 senderIndex) public {
        // Copy of testMerkleSuccess
        vm.assume(allowlist.length > 1);
        vm.assume(senderIndex < allowlist.length);
        bytes32[] memory addrs = new bytes32[](allowlist.length);
        address sender = allowlist[senderIndex];
        vm.assume(sender != address(0));
        for (uint256 i = 0; i < allowlist.length; i++) {
            addrs[i] = keccak256(abi.encodePacked(allowlist[i]));
        }
        bytes32 root = getRoot(addrs);
        sale.setSaleDetails(0, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), root);

        bytes32[] memory proof = getProof(addrs, senderIndex);

        vm.prank(sender);
        sale.mint(sender, 1, proof);

        assertEq(1, token.balanceOf(sender));
        // End copy

        vm.expectRevert(abi.encodeWithSelector(MerkleProofInvalid.selector, root, proof, sender));
        vm.prank(sender);
        sale.mint(sender, 1, proof);
    }

    // Minting with merkle fail no proof.
    function testMerkleFailNoProof(address[] memory allowlist, address sender) public {
        // Construct a merkle tree with the allowlist.
        vm.assume(allowlist.length > 1);
        bytes32[] memory addrs = new bytes32[](allowlist.length);
        for (uint256 i = 0; i < allowlist.length; i++) {
            vm.assume(sender != allowlist[i]);
            addrs[i] = keccak256(abi.encodePacked(allowlist[i]));
        }
        bytes32 root = getRoot(addrs);
        sale.setSaleDetails(0, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), root);

        bytes32[] memory proof = TestHelper.blankProof();

        vm.expectRevert(abi.encodeWithSelector(MerkleProofInvalid.selector, root, proof, sender));
        vm.prank(sender);
        sale.mint(sender, 1, TestHelper.blankProof());
    }

    // Minting with merkle fail bad proof.
    function testMerkleFailBadProof(address[] memory allowlist, address sender) public {
        // Construct a merkle tree with the allowlist.
        vm.assume(allowlist.length > 1);
        bytes32[] memory addrs = new bytes32[](allowlist.length);
        for (uint256 i = 0; i < allowlist.length; i++) {
            vm.assume(sender != allowlist[i]);
            addrs[i] = keccak256(abi.encodePacked(allowlist[i]));
        }
        bytes32 root = getRoot(addrs);
        sale.setSaleDetails(0, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), root);

        bytes32[] memory proof = getProof(addrs, 1); // Wrong sender

        vm.expectRevert(abi.encodeWithSelector(MerkleProofInvalid.selector, root, proof, sender));
        vm.prank(sender);
        sale.mint(sender, 1, proof);
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
    function testWithdrawETH(bool useFactory, address withdrawTo, uint256 amount) public withFactory(useFactory) {
        assumeSafeAddress(withdrawTo);
        testMintSuccess(false, withdrawTo, amount);

        uint256 saleBalance = address(sale).balance;
        uint256 balance = withdrawTo.balance;
        sale.withdrawETH(withdrawTo, saleBalance);
        assertEq(saleBalance + balance, withdrawTo.balance);
    }

    // Withdraw success ERC20
    function testWithdrawERC20(bool useFactory, address withdrawTo, uint256 amount) public withFactory(useFactory) {
        testERC20Mint(false, withdrawTo, amount);

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

    modifier assumeSafe(address nonContract, uint256 amount) {
        vm.assume(uint160(nonContract) > 16);
        vm.assume(nonContract.code.length == 0);
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

    modifier withSaleActive() {
        sale.setSaleDetails(0, perTokenCost, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), "");
        _;
    }
}
