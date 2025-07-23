// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { TestHelper } from "../../../../TestHelper.sol";
import { ERC20Mock } from "../../../../_mocks/ERC20Mock.sol";

import { ERC721Items } from "src/tokens/ERC721/presets/items/ERC721Items.sol";
import { ERC721Sale } from "src/tokens/ERC721/utility/sale/ERC721Sale.sol";
import { ERC721SaleFactory } from "src/tokens/ERC721/utility/sale/ERC721SaleFactory.sol";
import { IERC721SaleFunctions, IERC721SaleSignals } from "src/tokens/ERC721/utility/sale/IERC721Sale.sol";
import { IMerkleProofSingleUseSignals } from "src/tokens/common/IMerkleProofSingleUse.sol";

// solhint-disable not-rely-on-time

contract ERC721SaleMintTest is TestHelper, IERC721SaleSignals, IMerkleProofSingleUseSignals {

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
        token.initialize(address(this), "test", "test", "ipfs://", "ipfs://", address(this), 0, address(0), bytes32(0));

        sale = new ERC721Sale();
        sale.initialize(address(this), address(token), address(0), bytes32(0));

        token.grantRole(keccak256("MINTER_ROLE"), address(sale));

        vm.deal(address(this), 100 ether);
    }

    function setUpFromFactory() public {
        ERC721SaleFactory factory = new ERC721SaleFactory(address(this));
        sale = ERC721Sale(factory.deploy(0, proxyOwner, address(this), address(token), address(0), bytes32(0)));
        token.grantRole(keccak256("MINTER_ROLE"), address(sale));
    }

    //
    // Minting
    //

    // Minting denied when no sale active.
    function testMintInactiveFail(bool useFactory, address mintTo, uint256 amount) public withFactory(useFactory) {
        assumeSafeAddress(mintTo);
        amount = bound(amount, 1, 20);
        uint256 cost = amount * perTokenCost;
        vm.expectRevert(SaleInactive.selector);
        sale.mint{ value: cost }(mintTo, amount, address(0), cost, TestHelper.blankProof());
    }

    // Minting denied when sale is expired or not started.
    function testMintExpiredFail(
        bool useFactory,
        address mintTo,
        uint256 amount,
        uint64 startTime,
        uint64 endTime
    ) public withFactory(useFactory) {
        assumeSafeAddress(mintTo);
        amount = bound(amount, 1, 20);
        startTime = uint64(bound(startTime, 0, type(uint64).max - 1));
        endTime = uint64(bound(endTime, 0, type(uint64).max - 1));

        if (startTime > endTime) {
            uint64 temp = startTime;
            startTime = endTime;
            endTime = temp;
        }
        if (endTime == 0) {
            endTime++;
        }

        vm.warp(uint256(endTime) - 1);
        sale.setSaleDetails(type(uint256).max, perTokenCost, address(0), uint64(startTime), uint64(endTime), "");
        vm.warp(uint256(endTime) + 1);

        uint256 cost = amount * perTokenCost;

        vm.expectRevert(SaleInactive.selector);
        sale.mint{ value: cost }(mintTo, amount, address(0), cost, TestHelper.blankProof());
    }

    // Minting denied when supply exceeded.
    function testMintSupplyExceeded(
        bool useFactory,
        address mintTo,
        uint256 amount,
        uint256 remainingSupply
    ) public withFactory(useFactory) {
        assumeSafeAddress(mintTo);
        amount = bound(amount, 2, 20);
        remainingSupply = bound(remainingSupply, 1, amount - 1);
        sale.setSaleDetails(
            remainingSupply, perTokenCost, address(0), uint64(block.timestamp), uint64(block.timestamp + 1), ""
        );
        uint256 cost = amount * perTokenCost;

        vm.expectRevert(abi.encodeWithSelector(InsufficientSupply.selector, remainingSupply, amount));
        sale.mint{ value: cost }(mintTo, amount, address(0), cost, TestHelper.blankProof());
    }

    // Minting allowed when sale is active.
    function testMintSuccess(
        bool useFactory,
        address mintTo,
        uint256 amount,
        uint256 remainingSupply
    ) public withFactory(useFactory) {
        assumeSafeAddress(mintTo);
        amount = bound(amount, 1, 20);
        remainingSupply = bound(remainingSupply, amount, type(uint256).max);

        sale.setSaleDetails(
            remainingSupply, perTokenCost, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), ""
        );

        uint256 count = token.balanceOf(mintTo);
        uint256 cost = amount * perTokenCost;
        vm.expectEmit(true, true, true, true, address(token));
        emit Transfer(address(0), mintTo, 0);
        vm.expectEmit(true, true, true, true, address(sale));
        emit ItemsMinted(mintTo, amount);
        sale.mint{ value: cost }(mintTo, amount, address(0), cost, TestHelper.blankProof());
        assertEq(count + amount, token.balanceOf(mintTo));

        // Check supply updated
        IERC721SaleFunctions.SaleDetails memory saleDetails = sale.saleDetails();
        assertEq(saleDetails.remainingSupply, remainingSupply - amount);
    }

    // Minting allowed when sale is free.
    function testFreeMint(bool useFactory, address mintTo, uint256 amount) public withFactory(useFactory) {
        assumeSafeAddress(mintTo);
        amount = bound(amount, 1, 20);
        sale.setSaleDetails(
            type(uint256).max, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), ""
        );

        uint256 count = token.balanceOf(mintTo);
        vm.expectEmit(true, true, true, true, address(token));
        emit Transfer(address(0), mintTo, 0);
        vm.expectEmit(true, true, true, true, address(sale));
        emit ItemsMinted(mintTo, amount);
        sale.mint(mintTo, amount, address(0), 0, TestHelper.blankProof());
        assertEq(count + amount, token.balanceOf(mintTo));
    }

    // Minting allowed when mint charged with ERC20.
    function testERC20Mint(
        bool useFactory,
        address mintTo,
        uint256 amount,
        uint256 remainingSupply
    ) public withFactory(useFactory) withERC20 {
        assumeSafeAddress(mintTo);
        amount = bound(amount, 1, 20);
        remainingSupply = bound(remainingSupply, amount, type(uint256).max);
        sale.setSaleDetails(
            remainingSupply, perTokenCost, address(erc20), uint64(block.timestamp - 1), uint64(block.timestamp + 1), ""
        );
        uint256 cost = amount * perTokenCost;

        uint256 balance = erc20.balanceOf(address(this));
        uint256 count = token.balanceOf(mintTo);
        vm.expectEmit(true, true, true, true, address(token));
        emit Transfer(address(0), mintTo, 0);
        vm.expectEmit(true, true, true, true, address(sale));
        emit ItemsMinted(mintTo, amount);
        sale.mint(mintTo, amount, address(erc20), cost, TestHelper.blankProof());
        assertEq(count + amount, token.balanceOf(mintTo));
        assertEq(balance - cost, erc20.balanceOf(address(this)));
        assertEq(cost, erc20.balanceOf(address(sale)));
    }

    // Minting fails with invalid maxTotal.
    function testERC20MintFailMaxTotal(
        bool useFactory,
        address mintTo,
        uint256 amount
    ) public withFactory(useFactory) withERC20 {
        assumeSafeAddress(mintTo);
        amount = bound(amount, 1, 20);
        sale.setSaleDetails(
            type(uint256).max,
            perTokenCost,
            address(erc20),
            uint64(block.timestamp - 1),
            uint64(block.timestamp + 1),
            ""
        );
        uint256 cost = amount * perTokenCost;

        vm.expectRevert(abi.encodeWithSelector(InsufficientPayment.selector, address(erc20), cost, cost - 1));
        sale.mint(mintTo, amount, address(erc20), cost - 1, TestHelper.blankProof());
    }

    // Minting fails with invalid maxTotal.
    function testETHMintFailMaxTotal(bool useFactory, address mintTo, uint256 amount) public withFactory(useFactory) {
        assumeSafeAddress(mintTo);
        amount = bound(amount, 1, 20);
        sale.setSaleDetails(
            type(uint256).max, perTokenCost, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), ""
        );
        uint256 cost = amount * perTokenCost;
        vm.deal(address(this), cost);

        vm.expectRevert(abi.encodeWithSelector(InsufficientPayment.selector, address(0), cost, cost - 1));
        sale.mint(mintTo, amount, address(0), cost - 1, TestHelper.blankProof());
    }

    // Minting fails with invalid payment token.
    function testMintFailWrongPaymentToken(
        bool useFactory,
        address mintTo,
        uint256 amount,
        address wrongToken
    ) public withFactory(useFactory) withERC20 {
        assumeSafeAddress(mintTo);
        amount = bound(amount, 1, 20);
        address paymentToken = wrongToken == address(0) ? address(erc20) : address(0);
        sale.setSaleDetails(
            type(uint256).max, 0, paymentToken, uint64(block.timestamp - 1), uint64(block.timestamp + 1), ""
        );

        vm.expectRevert(abi.encodeWithSelector(InsufficientPayment.selector, paymentToken, 0, 0));
        sale.mint(mintTo, amount, wrongToken, 0, TestHelper.blankProof());
    }

    // Minting fails with invalid payment token.
    function testERC20MintFailPaidETH(
        bool useFactory,
        address mintTo,
        uint256 amount
    ) public withFactory(useFactory) withERC20 {
        assumeSafeAddress(mintTo);
        amount = bound(amount, 1, 20);
        sale.setSaleDetails(
            type(uint256).max, 0, address(erc20), uint64(block.timestamp - 1), uint64(block.timestamp + 1), ""
        );

        vm.expectRevert(abi.encodeWithSelector(InsufficientPayment.selector, address(0), 0, 1));
        sale.mint{ value: 1 }(mintTo, amount, address(erc20), 0, TestHelper.blankProof());
    }

    // Minting with merkle success.
    function testMerkleSuccess(address[] memory allowlist, uint256 senderIndex) public {
        // Construct a merkle tree with the allowlist.
        vm.assume(allowlist.length > 1);
        senderIndex = bound(senderIndex, 0, allowlist.length - 1);
        address sender = allowlist[senderIndex];
        vm.assume(sender != address(0));

        (bytes32 root, bytes32[] memory proof) = TestHelper.getMerkleParts(allowlist, 0, senderIndex);

        sale.setSaleDetails(
            type(uint256).max, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), root
        );

        vm.expectEmit(true, true, true, true, address(sale));
        emit ItemsMinted(sender, 1);
        vm.prank(sender);
        sale.mint(sender, 1, address(0), 0, proof);

        assertEq(1, token.balanceOf(sender));
    }

    // Minting with merkle reuse fail.
    function testMerkleReuseFail(address[] memory allowlist, uint256 senderIndex) public {
        // Copy of testMerkleSuccess
        vm.assume(allowlist.length > 1);
        senderIndex = bound(senderIndex, 0, allowlist.length - 1);
        address sender = allowlist[senderIndex];
        vm.assume(sender != address(0));

        (bytes32 root, bytes32[] memory proof) = TestHelper.getMerkleParts(allowlist, 0, senderIndex);

        sale.setSaleDetails(
            type(uint256).max, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), root
        );

        vm.prank(sender);
        sale.mint(sender, 1, address(0), 0, proof);

        assertEq(1, token.balanceOf(sender));
        // End copy

        vm.expectRevert(abi.encodeWithSelector(MerkleProofInvalid.selector, root, proof, sender, uint256(0)));
        vm.prank(sender);
        sale.mint(sender, 1, address(0), 0, proof);
    }

    // Minting with merkle fail no proof.
    function testMerkleFailNoProof(address[] memory allowlist, address sender) public {
        // Construct a merkle tree with the allowlist.
        vm.assume(allowlist.length > 1);

        (bytes32 root,) = TestHelper.getMerkleParts(allowlist, 0, 0);
        bytes32[] memory proof = TestHelper.blankProof();

        sale.setSaleDetails(
            type(uint256).max, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), root
        );

        vm.expectRevert(abi.encodeWithSelector(MerkleProofInvalid.selector, root, proof, sender, uint256(0)));
        vm.prank(sender);
        sale.mint(sender, 1, address(0), 0, TestHelper.blankProof());
    }

    // Minting with merkle fail bad proof.
    function testMerkleFailBadProof(address[] memory allowlist, address sender) public {
        // Construct a merkle tree with the allowlist.
        vm.assume(allowlist.length > 1);
        vm.assume(allowlist[1] != sender);

        (bytes32 root, bytes32[] memory proof) = TestHelper.getMerkleParts(allowlist, 0, 1); // Wrong sender
        sale.setSaleDetails(
            type(uint256).max, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), root
        );

        vm.expectRevert(abi.encodeWithSelector(MerkleProofInvalid.selector, root, proof, sender, uint256(0)));
        vm.prank(sender);
        sale.mint(sender, 1, address(0), 0, proof);
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

    // Create ERC20. Give this contract 1000 ERC20 tokens. Approve token to spend 100 ERC20 tokens.
    modifier withERC20() {
        erc20 = new ERC20Mock(address(this));
        erc20.mint(address(this), 1000 ether);
        erc20.approve(address(sale), 1000 ether);
        _;
    }

}
