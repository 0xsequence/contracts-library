// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {ERC1155Sale} from "src/tokens/ERC1155/presets/sale/ERC1155Sale.sol";
import {ERC1155SaleFactory} from "src/tokens/ERC1155/presets/sale/ERC1155SaleFactory.sol";
import {ERC1155SaleErrors} from "src/tokens/ERC1155/presets/sale/ERC1155SaleErrors.sol";
import {ERC1155SupplyErrors} from "src/tokens/ERC1155/extensions/supply/ERC1155SupplyErrors.sol";

import {Merkle} from "murky/Merkle.sol";
import {ERC20Mock} from "@0xsequence/erc20-meta-token/contracts/mocks/ERC20Mock.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {TestHelper} from "test/tokens/TestHelper.sol";
import {MerkleProofInvalid} from "@0xsequence/contracts-library/tokens/common/MerkleProofSingleUse.sol";

// Interfaces
import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {IERC1155Metadata} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155Metadata.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

// solhint-disable no-rely-on-time

contract ERC1155SaleTest is Test, Merkle, ERC1155SaleErrors, ERC1155SupplyErrors {
    // Redeclare events
    event TransferBatch(
        address indexed _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _amounts
    );

    ERC1155Sale private token;
    ERC20Mock private erc20;
    uint256 private perTokenCost = 0.02 ether;

    address private constant ALLOWLIST_ADDR = 0xFA4eE536359087Fba7BD3248EE09e8Cc8347F8Ed;

    function setUp() public {
        token = new ERC1155Sale();
        token.initialize(address(this), "test", "ipfs://");

        vm.deal(address(this), 1e6 ether);
    }

    function setUpFromFactory() public {
        ERC1155SaleFactory factory = new ERC1155SaleFactory();
        token = ERC1155Sale(factory.deployERC1155Sale(address(this), "test", "ipfs://", ""));
    }

    function testSupportsInterface() public {
        assertTrue(token.supportsInterface(type(IERC165).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155Metadata).interfaceId));
        assertTrue(token.supportsInterface(type(IAccessControl).interfaceId));
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

        vm.expectRevert(abi.encodeWithSelector(SaleInactive.selector, tokenId));
        token.mint{value: amount * perTokenCost}(mintTo, tokenIds, amounts, "", TestHelper.blankProof());
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

        vm.expectRevert(abi.encodeWithSelector(SaleInactive.selector, tokenId));
        token.mint{value: amount * perTokenCost}(mintTo, tokenIds, amounts, "", TestHelper.blankProof());
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
        token.setTokenSaleDetails(tokenId, perTokenCost, 0, startTime, endTime, "");

        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);

        vm.expectRevert(abi.encodeWithSelector(SaleInactive.selector, tokenId));
        token.mint{value: amount * perTokenCost}(mintTo, tokenIds, amounts, "", TestHelper.blankProof());
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
        token.setGlobalSaleDetails(perTokenCost, 0, address(0), startTime, endTime, "");

        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);

        vm.expectRevert(abi.encodeWithSelector(SaleInactive.selector, tokenId));
        token.mint{value: amount * perTokenCost}(mintTo, tokenIds, amounts, "", TestHelper.blankProof());
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

        vm.expectRevert(abi.encodeWithSelector(SaleInactive.selector, tokenId + 1));
        token.mint{value: amount * perTokenCost * 2}(mintTo, tokenIds, amounts, "", TestHelper.blankProof());
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
        token.setGlobalSaleDetails(
            perTokenCost, supplyCap, address(0), uint64(block.timestamp), uint64(block.timestamp + 1), ""
        );

        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);

        vm.expectRevert(abi.encodeWithSelector(InsufficientSupply.selector, 0, amount, supplyCap));
        token.mint{value: amount * perTokenCost}(mintTo, tokenIds, amounts, "", TestHelper.blankProof());
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
        token.setTokenSaleDetails(
            tokenId, perTokenCost, supplyCap, uint64(block.timestamp), uint64(block.timestamp + 1), ""
        );

        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);

        vm.expectRevert(abi.encodeWithSelector(InsufficientSupply.selector, 0, amount, supplyCap));
        token.mint{value: amount * perTokenCost}(mintTo, tokenIds, amounts, "", TestHelper.blankProof());
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

        uint256 count = token.balanceOf(mintTo, tokenId);
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(address(this), address(0), mintTo, tokenIds, amounts);
        token.mint{value: amount * perTokenCost}(mintTo, tokenIds, amounts, "", TestHelper.blankProof());
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

        uint256 count = token.balanceOf(mintTo, tokenId);
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(address(this), address(0), mintTo, tokenIds, amounts);
        token.mint{value: amount * perTokenCost}(mintTo, tokenIds, amounts, "", TestHelper.blankProof());
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

        uint256 count = token.balanceOf(mintTo, tokenId);
        uint256 count2 = token.balanceOf(mintTo, tokenId + 1);
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(address(this), address(0), mintTo, tokenIds, amounts);
        token.mint{value: amount * perTokenCost * 2}(mintTo, tokenIds, amounts, "", TestHelper.blankProof());
        assertEq(count + amount, token.balanceOf(mintTo, tokenId));
        assertEq(count2 + amount, token.balanceOf(mintTo, tokenId + 1));
    }

    // Minting allowed when global sale is free.
    function testFreeGlobalMint(bool useFactory, address mintTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(mintTo, tokenId, amount)
        withFactory(useFactory)
    {
        token.setGlobalSaleDetails(0, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), "");
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);

        uint256 count = token.balanceOf(mintTo, tokenId);
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(address(this), address(0), mintTo, tokenIds, amounts);
        token.mint(mintTo, tokenIds, amounts, "", TestHelper.blankProof());
        assertEq(count + amount, token.balanceOf(mintTo, tokenId));
    }

    // Minting allowed when token sale is free and global is not.
    function testFreeTokenMint(bool useFactory, address mintTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(mintTo, tokenId, amount)
        withFactory(useFactory)
        withGlobalSaleActive
    {
        token.setTokenSaleDetails(tokenId, 0, 0, uint64(block.timestamp - 1), uint64(block.timestamp + 1), "");
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);

        uint256 count = token.balanceOf(mintTo, tokenId);
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(address(this), address(0), mintTo, tokenIds, amounts);
        token.mint(mintTo, tokenIds, amounts, "", TestHelper.blankProof());
        assertEq(count + amount, token.balanceOf(mintTo, tokenId));
    }

    // Minting allowed when mint charged with ERC20.
    function testERC20Mint(bool useFactory, address mintTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(mintTo, tokenId, amount)
        withFactory(useFactory)
        withERC20
    {
        token.setGlobalSaleDetails(
            perTokenCost, 0, address(erc20), uint64(block.timestamp - 1), uint64(block.timestamp + 1), ""
        );
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256 cost = amount * perTokenCost;

        uint256 balanace = erc20.balanceOf(address(this));
        uint256 count = token.balanceOf(mintTo, tokenId);
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(address(this), address(0), mintTo, tokenIds, amounts);
        token.mint(mintTo, tokenIds, amounts, "", TestHelper.blankProof());
        assertEq(count + amount, token.balanceOf(mintTo, tokenId));
        assertEq(balanace - cost, erc20.balanceOf(address(this)));
        assertEq(cost, erc20.balanceOf(address(token)));
    }

    // Minting with merkle success.
    function testMerkleSuccess(address[] memory allowlist, uint256 senderIndex, uint256 tokenId, bool globalActive)
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
        if (globalActive) {
            token.setGlobalSaleDetails(0, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), root);
        } else {
            token.setTokenSaleDetails(tokenId, 0, 0, uint64(block.timestamp - 1), uint64(block.timestamp + 1), root);
        }

        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(uint256(1));
        bytes32[] memory proof = getProof(addrs, senderIndex);

        address sender = allowlist[senderIndex];
        vm.prank(sender);
        token.mint(sender, tokenIds, amounts, "", proof);

        assertEq(1, token.balanceOf(sender, tokenId));
    }

    // Minting with merkle reuse fail.
    function testMerkleReuseFail(address[] memory allowlist, uint256 senderIndex, uint256 tokenId, bool globalActive)
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
        if (globalActive) {
            token.setGlobalSaleDetails(0, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), root);
        } else {
            token.setTokenSaleDetails(tokenId, 0, 0, uint64(block.timestamp - 1), uint64(block.timestamp + 1), root);
        }

        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(uint256(1));
        bytes32[] memory proof = getProof(addrs, senderIndex);

        address sender = allowlist[senderIndex];
        vm.prank(sender);
        token.mint(sender, tokenIds, amounts, "", proof);

        assertEq(1, token.balanceOf(sender, tokenId));
        // End copy

        vm.expectRevert(abi.encodeWithSelector(MerkleProofInvalid.selector, root, proof, sender));
        vm.prank(sender);
        token.mint(sender, tokenIds, amounts, "", proof);
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
            token.setGlobalSaleDetails(0, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), root);
        } else {
            token.setTokenSaleDetails(tokenId, 0, 0, uint64(block.timestamp - 1), uint64(block.timestamp + 1), root);
        }

        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(uint256(1));
        bytes32[] memory proof = TestHelper.blankProof();

        vm.expectRevert(abi.encodeWithSelector(MerkleProofInvalid.selector, root, proof, sender));
        vm.prank(sender);
        token.mint(sender, tokenIds, amounts, "", TestHelper.blankProof());
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
            token.setGlobalSaleDetails(0, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), root);
        } else {
            token.setTokenSaleDetails(tokenId, 0, 0, uint64(block.timestamp - 1), uint64(block.timestamp + 1), root);
        }

        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(uint256(1));
        bytes32[] memory proof = getProof(addrs, 1); // Wrong sender

        vm.expectRevert(abi.encodeWithSelector(MerkleProofInvalid.selector, root, proof, sender));
        vm.prank(sender);
        token.mint(sender, tokenIds, amounts, "", proof);
    }

    //
    // Admin minting
    //

    // Admin minting denied when not admin.
    function testMintAdminFail(bool useFactory, address minter, address mintTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(mintTo, tokenId, amount)
        withFactory(useFactory)
    {
        vm.assume(minter != address(this));
        vm.assume(minter != address(0));

        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(minter),
                " is missing role ",
                Strings.toHexString(uint256(token.MINT_ADMIN_ROLE()), 32)
            )
        );
        vm.prank(minter);
        token.mintAdmin(mintTo, tokenIds, amounts, "");
    }

    // Minting as admin success.
    function testMintAdminSuccess(bool useFactory, address minter, address mintTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(mintTo, tokenId, amount)
        withFactory(useFactory)
    {
        token.grantRole(token.MINT_ADMIN_ROLE(), minter);

        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);

        uint256 count = token.balanceOf(mintTo, tokenId);
        token.mintAdmin(mintTo, tokenIds, amounts, "");
        assertEq(count + amount, token.balanceOf(mintTo, tokenId));
    }

    //
    // Royalty
    //

    // Token royalty fails if the caller doesn't have the ROYALTY_ADMIN_ROLE
    function testSetTokenRoyaltyFail(uint256 _tokenId, address _receiver, uint96 _feeNumerator) public {
        token.revokeRole(token.ROYALTY_ADMIN_ROLE(), address(this));

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(address(this)),
                " is missing role ",
                Strings.toHexString(uint256(token.ROYALTY_ADMIN_ROLE()), 32)
            )
        );
        token.setTokenRoyalty(_tokenId, _receiver, _feeNumerator);
    }

    // Default royalty fails if the caller doesn't have the ROYALTY_ADMIN_ROLE
    function testSetDefaultRoyaltyFail(address _receiver, uint96 _feeNumerator) public {
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

    // Royalty calculation for token with custom royalty information
    function testRoyaltyInfoCustom(uint256 _tokenId, uint256 _salePrice, address _receiver, uint96 _feeNumerator)
        public
    {
        vm.assume(_receiver != address(0));
        vm.assume(_feeNumerator < 10000);
        vm.assume(_salePrice < 10000 ether);

        token.setTokenRoyalty(_tokenId, _receiver, _feeNumerator);
        uint256 expectedRoyaltyAmount = (_salePrice * _feeNumerator) / 10000;

        (address receiver, uint256 royaltyAmount) = token.royaltyInfo(_tokenId, _salePrice);

        assertEq(_receiver, receiver);
        assertEq(expectedRoyaltyAmount, royaltyAmount);
    }

    // Test royalty calculation for token with default royalty information
    function testRoyaltyInfoDefault(uint256 _tokenId, uint256 _salePrice, address _receiver, uint96 _feeNumerator)
        public
    {
        vm.assume(_receiver != address(0));
        vm.assume(_feeNumerator < 10000);
        vm.assume(_salePrice < 10000 ether);

        token.setDefaultRoyalty(_receiver, _feeNumerator);
        uint256 expectedRoyaltyAmount = (_salePrice * _feeNumerator) / 10000;

        (address receiver, uint256 royaltyAmount) = token.royaltyInfo(_tokenId, _salePrice);

        assertEq(_receiver, receiver);
        assertEq(expectedRoyaltyAmount, royaltyAmount);
    }

    //
    // Withdraw
    //

    // Withdraw fails if the caller doesn't have the WITHDRAW_ROLE
    function testWithdrawFail(bool useFactory, address withdrawTo, uint256 amount) public withFactory(useFactory) {
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
    function testWithdrawETH(bool useFactory, address withdrawTo, uint256 tokenId, uint256 amount)
        public
        withFactory(useFactory)
    {
        // Address 9 doesnt receive ETH
        vm.assume(withdrawTo != address(9));
        testMintSingleSuccess(false, withdrawTo, tokenId, amount);

        uint256 tokenBalance = address(token).balance;
        uint256 balance = withdrawTo.balance;
        token.withdrawETH(withdrawTo, tokenBalance);
        assertEq(tokenBalance + balance, withdrawTo.balance);
    }

    // Withdraw success ERC20
    function testWithdrawERC20(bool useFactory, address withdrawTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(withdrawTo, tokenId, amount)
        withFactory(useFactory)
    {
        testERC20Mint(false, withdrawTo, tokenId, amount);

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

    modifier assumeSafe(address nonContract, uint256 tokenId, uint256 amount) {
        vm.assume(uint160(nonContract) > 16);
        vm.assume(nonContract.code.length == 0);
        vm.assume(tokenId < 100);
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

    modifier withGlobalSaleActive() {
        token.setGlobalSaleDetails(
            perTokenCost, 0, address(0), uint64(block.timestamp - 1), uint64(block.timestamp + 1), ""
        );
        _;
    }

    modifier withTokenSaleActive(uint256 tokenId) {
        setTokenSaleActive(tokenId);
        _;
    }

    function setTokenSaleActive(uint256 tokenId) private {
        token.setTokenSaleDetails(
            tokenId, perTokenCost, 0, uint64(block.timestamp - 1), uint64(block.timestamp + 1), ""
        );
    }
}
