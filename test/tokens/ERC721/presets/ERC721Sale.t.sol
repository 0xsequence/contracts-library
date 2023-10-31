// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {ERC721Sale} from "src/tokens/ERC721/presets/sale/ERC721Sale.sol";
import {IERC721SaleSignals} from "src/tokens/ERC721/presets/sale/IERC721Sale.sol";
import {ERC721SaleFactory} from "src/tokens/ERC721/presets/sale/ERC721SaleFactory.sol";

import {Merkle} from "murky/Merkle.sol";
import {ERC20Mock} from "@0xsequence/erc20-meta-token/contracts/mocks/ERC20Mock.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {TestHelper} from "test/tokens/TestHelper.sol";
import {IMerkleProofSingleUseSignals} from "@0xsequence/contracts-library/tokens/common/IMerkleProofSingleUse.sol";

// Interfaces
import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721A} from "erc721a/contracts/interfaces/IERC721A.sol";
import {IERC721AQueryable} from "erc721a/contracts/interfaces/IERC721AQueryable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// solhint-disable no-rely-on-time

contract ERC721SaleTest is Test, Merkle, IERC721SaleSignals, IMerkleProofSingleUseSignals {
    // Redeclare events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    ERC721Sale private token;
    ERC20Mock private erc20;
    uint256 private perTokenCost = 0.02 ether;

    address private proxyOwner;

    function setUp() public {
        proxyOwner = makeAddr("proxyOwner");

        token = new ERC721Sale();
        token.initialize(address(this), "test", "test", "ipfs://", address(this), 0);

        vm.deal(address(this), 100 ether);
    }

    function setUpFromFactory() public {
        ERC721SaleFactory factory = new ERC721SaleFactory(address(this));
        token = ERC721Sale(factory.deploy(proxyOwner, address(this), "test", "test", "ipfs://", address(this), 0));
    }

    function testSupportsInterface() public {
        assertTrue(token.supportsInterface(type(IERC165).interfaceId));
        assertTrue(token.supportsInterface(type(IERC721).interfaceId));
        assertTrue(token.supportsInterface(type(IERC721A).interfaceId));
        assertTrue(token.supportsInterface(type(IERC721AQueryable).interfaceId));
        assertTrue(token.supportsInterface(type(IAccessControl).interfaceId));
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
        token.mint{value: amount * perTokenCost}(mintTo, amount, TestHelper.blankProof());
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
        token.setSaleDetails(0, perTokenCost, address(0), uint64(startTime), uint64(endTime), "");

        vm.expectRevert(SaleInactive.selector);
        token.mint{value: amount * perTokenCost}(mintTo, amount, TestHelper.blankProof());
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
        token.setSaleDetails(supplyCap, perTokenCost, address(0), uint64(block.timestamp), uint64(block.timestamp + 1), "");

        vm.expectRevert(abi.encodeWithSelector(InsufficientSupply.selector, 0, amount, supplyCap));
        token.mint{value: amount * perTokenCost}(mintTo, amount, TestHelper.blankProof());
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
        token.mint{value: amount * perTokenCost}(mintTo, amount, TestHelper.blankProof());
        assertEq(count + amount, token.balanceOf(mintTo));
    }

    // Minting allowed when sale is free.
    function testFreeMint(bool useFactory, address mintTo, uint256 amount)
        public
        assumeSafe(mintTo, amount)
        withFactory(useFactory)
    {
        token.setSaleDetails(0, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), "");

        uint256 count = token.balanceOf(mintTo);
        vm.expectEmit(true, true, true, true, address(token));
        emit Transfer(address(0), mintTo, 0);
        token.mint(mintTo, amount, TestHelper.blankProof());
        assertEq(count + amount, token.balanceOf(mintTo));
    }

    // Minting allowed when mint charged with ERC20.
    function testERC20Mint(bool useFactory, address mintTo, uint256 amount)
        public
        assumeSafe(mintTo, amount)
        withFactory(useFactory)
        withERC20
    {
        token.setSaleDetails(0, perTokenCost, address(erc20), uint64(block.timestamp - 1), uint64(block.timestamp + 1), "");
        uint256 cost = amount * perTokenCost;

        uint256 balanace = erc20.balanceOf(address(this));
        uint256 count = token.balanceOf(mintTo);
        vm.expectEmit(true, true, true, true, address(token));
        emit Transfer(address(0), mintTo, 0);
        token.mint(mintTo, amount, TestHelper.blankProof());
        assertEq(count + amount, token.balanceOf(mintTo));
        assertEq(balanace - cost, erc20.balanceOf(address(this)));
        assertEq(cost, erc20.balanceOf(address(token)));
    }

    // Minting with merkle success.
    function testMerkleSuccess(address[] memory allowlist, uint256 senderIndex)
        public
    {
        // Construct a merkle tree with the allowlist.
        vm.assume(allowlist.length > 1);
        vm.assume(senderIndex < allowlist.length);
        bytes32[] memory addrs = new bytes32[](allowlist.length);
        for (uint256 i = 0; i < allowlist.length; i++) {
            addrs[i] = keccak256(abi.encodePacked(allowlist[i]));
        }
        bytes32 root = getRoot(addrs);
        token.setSaleDetails(0, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), root);

        bytes32[] memory proof = getProof(addrs, senderIndex);

        address sender = allowlist[senderIndex];
        vm.prank(sender);
        token.mint(sender, 1, proof);

        assertEq(1, token.balanceOf(sender));
    }

    // Minting with merkle reuse fail.
    function testMerkleReuseFail(address[] memory allowlist, uint256 senderIndex)
        public
    {
        // Copy of testMerkleSuccess
        vm.assume(allowlist.length > 1);
        vm.assume(senderIndex < allowlist.length);
        bytes32[] memory addrs = new bytes32[](allowlist.length);
        for (uint256 i = 0; i < allowlist.length; i++) {
            addrs[i] = keccak256(abi.encodePacked(allowlist[i]));
        }
        bytes32 root = getRoot(addrs);
        token.setSaleDetails(0, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), root);

        bytes32[] memory proof = getProof(addrs, senderIndex);

        address sender = allowlist[senderIndex];
        vm.prank(sender);
        token.mint(sender, 1, proof);

        assertEq(1, token.balanceOf(sender));
        // End copy

        vm.expectRevert(abi.encodeWithSelector(MerkleProofInvalid.selector, root, proof, sender));
        vm.prank(sender);
        token.mint(sender, 1, proof);
    }

    // Minting with merkle fail no proof.
    function testMerkleFailNoProof(address[] memory allowlist, address sender)
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
        token.setSaleDetails(0, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), root);

        bytes32[] memory proof = TestHelper.blankProof();

        vm.expectRevert(abi.encodeWithSelector(MerkleProofInvalid.selector, root, proof, sender));
        vm.prank(sender);
        token.mint(sender, 1, TestHelper.blankProof());
    }

    // Minting with merkle fail bad proof.
    function testMerkleFailBadProof(address[] memory allowlist, address sender)
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
        token.setSaleDetails(0, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), root);

        bytes32[] memory proof = getProof(addrs, 1); // Wrong sender

        vm.expectRevert(abi.encodeWithSelector(MerkleProofInvalid.selector, root, proof, sender));
        vm.prank(sender);
        token.mint(sender, 1, proof);
    }

    //
    // Admin minting
    //

    // Admin minting denied when not admin.
    function testMintAdminFail(address minter, address mintTo, uint256 amount) public assumeSafe(mintTo, amount) {
        vm.assume(minter != address(this));
        vm.assume(minter != address(0));

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(minter),
                " is missing role ",
                Strings.toHexString(uint256(token.MINT_ADMIN_ROLE()), 32)
            )
        );
        vm.prank(minter);
        token.mintAdmin(mintTo, amount);
    }

    // Minting as admin success.
    function testMintAdminSuccess(address minter, address mintTo, uint256 amount) public assumeSafe(mintTo, amount) {
        token.grantRole(token.MINT_ADMIN_ROLE(), minter);

        uint256 count = token.balanceOf(mintTo);
        token.mintAdmin(mintTo, amount);
        assertEq(count + amount, token.balanceOf(mintTo));
    }

    //
    // Royalty
    //

    // Set royalty fails if the caller doesn't have the ROYALTY_ADMIN_ROLE
    function testSetRoyaltyFail(address _receiver, uint96 _feeNumerator) public {
        token.revokeRole(token.ROYALTY_ADMIN_ROLE(), address(this));

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(address(this)),
                " is missing role ",
                Strings.toHexString(uint256(token.ROYALTY_ADMIN_ROLE()), 32)
            )
        );
        token.setDefaultRoyalty(_receiver, _feeNumerator);
    }

    // Test royalty calculation for token with royalty information
    function testRoyaltyInfo(uint256 _salePrice, address _receiver, uint96 _feeNumerator) public {
        vm.assume(_receiver != address(0));
        vm.assume(_feeNumerator < 10000);
        vm.assume(_salePrice < 10000 ether);

        token.setDefaultRoyalty(_receiver, _feeNumerator);
        uint256 expectedRoyaltyAmount = (_salePrice * _feeNumerator) / 10000;

        (address receiver, uint256 royaltyAmount) = token.royaltyInfo(0, _salePrice);

        assertEq(_receiver, receiver);
        assertEq(expectedRoyaltyAmount, royaltyAmount);
    }

    //
    // Withdraw
    //

    // Withdraw fails if the caller doesn't have the WITHDRAW_ROLE
    function testWithdrawFail(address withdrawTo, uint256 amount) public {
        token.revokeRole(token.WITHDRAW_ROLE(), address(this));

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(address(this)),
                " is missing role ",
                Strings.toHexString(uint256(token.WITHDRAW_ROLE()), 32)
            )
        );
        token.withdrawETH(withdrawTo, amount);

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(address(this)),
                " is missing role ",
                Strings.toHexString(uint256(token.WITHDRAW_ROLE()), 32)
            )
        );
        token.withdrawERC20(address(erc20), withdrawTo, amount);
    }

    // Withdraw success ETH
    function testWithdrawETH(bool useFactory, address withdrawTo, uint256 amount) public withFactory(useFactory) {
        // Address 9 doesnt receive ETH
        vm.assume(withdrawTo != address(9));
        testMintSuccess(false, withdrawTo, amount);

        uint256 tokenBalance = address(token).balance;
        uint256 balance = withdrawTo.balance;
        token.withdrawETH(withdrawTo, tokenBalance);
        assertEq(tokenBalance + balance, withdrawTo.balance);
    }

    // Withdraw success ERC20
    function testWithdrawERC20(bool useFactory, address withdrawTo, uint256 amount) public withFactory(useFactory) {
        testERC20Mint(false, withdrawTo, amount);

        uint256 tokenBalance = erc20.balanceOf(address(token));
        uint256 balance = erc20.balanceOf(withdrawTo);
        token.withdrawERC20(address(erc20), withdrawTo, tokenBalance);
        assertEq(tokenBalance + balance, erc20.balanceOf(withdrawTo));
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
        erc20.approve(address(token), 1000 ether);
        _;
    }

    modifier withSaleActive() {
        token.setSaleDetails(0, perTokenCost, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), "");
        _;
    }
}
