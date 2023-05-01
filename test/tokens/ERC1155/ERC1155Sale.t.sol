// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {ERC1155Sale} from "src/tokens/ERC1155/ERC1155Sale.sol";
import {ERC1155SaleErrors} from "src/tokens/ERC1155/ERC1155SaleErrors.sol";

import {ERC20Mock} from "@0xsequence/erc20-meta-token/contracts/mocks/ERC20Mock.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// Interfaces
import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {IERC1155Metadata} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155Metadata.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract ERC1155SaleTest is Test, ERC1155SaleErrors {
    // Redeclare events
    event TransferBatch(
        address indexed _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _amounts
    );

    ERC1155Sale private token;
    ERC20Mock private erc20;
    uint256 private perTokenCost = 0.02 ether;

    function setUp() public {
        token = new ERC1155Sale(address(this), "test", "ipfs://");

        vm.deal(address(this), 100 ether);
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
    function testMintInactiveFail(address mintTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(mintTo, tokenId, amount)
    {
        uint256[] memory tokenIds = singleToArray(tokenId);
        uint256[] memory amounts = singleToArray(amount);

        vm.expectRevert(abi.encodeWithSelector(SaleInactive.selector, tokenId));
        token.mint{value: amount * perTokenCost}(mintTo, tokenIds, amounts, "");
    }

    // Minting denied when sale is active but not for the token.
    function testMintInactiveSingleFail(address mintTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(mintTo, tokenId, amount)
        withTokenSaleActive(tokenId + 1)
    {
        uint256[] memory tokenIds = singleToArray(tokenId);
        uint256[] memory amounts = singleToArray(amount);

        vm.expectRevert(abi.encodeWithSelector(SaleInactive.selector, tokenId));
        token.mint{value: amount * perTokenCost}(mintTo, tokenIds, amounts, "");
    }

    // Minting denied when token sale is expired.
    function testMintExpiredSingleFail(
        address mintTo,
        uint256 tokenId,
        uint256 amount,
        uint256 startTime,
        uint256 endTime
    )
        public
        assumeSafe(mintTo, tokenId, amount)
    {
        vm.assume(startTime > endTime);
        vm.assume(block.timestamp < startTime || block.timestamp >= endTime);
        token.setTokenSalesDetails(tokenId, perTokenCost, uint64(startTime), uint64(endTime));

        uint256[] memory tokenIds = singleToArray(tokenId);
        uint256[] memory amounts = singleToArray(amount);

        vm.expectRevert(abi.encodeWithSelector(SaleInactive.selector, tokenId));
        token.mint{value: amount * perTokenCost}(mintTo, tokenIds, amounts, "");
    }

    // Minting denied when global sale is expired.
    function testMintExpiredGlobalFail(
        address mintTo,
        uint256 tokenId,
        uint256 amount,
        uint256 startTime,
        uint256 endTime
    )
        public
        assumeSafe(mintTo, tokenId, amount)
    {
        vm.assume(startTime > endTime);
        vm.assume(block.timestamp < startTime || block.timestamp >= endTime);
        token.setGlobalSalesDetails(address(0), perTokenCost, uint64(startTime), uint64(endTime));

        uint256[] memory tokenIds = singleToArray(tokenId);
        uint256[] memory amounts = singleToArray(amount);

        vm.expectRevert(abi.encodeWithSelector(SaleInactive.selector, tokenId));
        token.mint{value: amount * perTokenCost}(mintTo, tokenIds, amounts, "");
    }

    // Minting denied when sale is active but not for all tokens in the group.
    function testMintInactiveInGroupFail(address mintTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(mintTo, tokenId, amount)
        withTokenSaleActive(tokenId)
    {
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId;
        tokenIds[1] = tokenId + 1;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount;

        vm.expectRevert(abi.encodeWithSelector(SaleInactive.selector, tokenId + 1));
        token.mint{value: amount * perTokenCost * 2}(mintTo, tokenIds, amounts, "");
    }

    // Minting allowed when sale is active globally.
    function testMintGlobalSuccess(address mintTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(mintTo, tokenId, amount)
        withGlobalSaleActive
    {
        uint256[] memory tokenIds = singleToArray(tokenId);
        uint256[] memory amounts = singleToArray(amount);

        uint256 count = token.balanceOf(mintTo, tokenId);
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(address(this), address(0), mintTo, tokenIds, amounts);
        token.mint{value: amount * perTokenCost}(mintTo, tokenIds, amounts, "");
        assertEq(count + amount, token.balanceOf(mintTo, tokenId));
    }

    // Minting allowed when sale is active for the token.
    function testMintSingleSuccess(address mintTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(mintTo, tokenId, amount)
        withTokenSaleActive(tokenId)
    {
        uint256[] memory tokenIds = singleToArray(tokenId);
        uint256[] memory amounts = singleToArray(amount);

        uint256 count = token.balanceOf(mintTo, tokenId);
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(address(this), address(0), mintTo, tokenIds, amounts);
        token.mint{value: amount * perTokenCost}(mintTo, tokenIds, amounts, "");
        assertEq(count + amount, token.balanceOf(mintTo, tokenId));
    }

    // Minting allowed when sale is active for both tokens individually.
    function testMintGroupSuccess(address mintTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(mintTo, tokenId, amount)
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
        token.mint{value: amount * perTokenCost * 2}(mintTo, tokenIds, amounts, "");
        assertEq(count + amount, token.balanceOf(mintTo, tokenId));
        assertEq(count2 + amount, token.balanceOf(mintTo, tokenId + 1));
    }

    // Minting allowed when global sale is free.
    function testFreeGlobalMint(address mintTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(mintTo, tokenId, amount)
    {
        token.setGlobalSalesDetails(address(0), 0, uint64(block.timestamp - 1), uint64(block.timestamp + 1));
        uint256[] memory tokenIds = singleToArray(tokenId);
        uint256[] memory amounts = singleToArray(amount);

        uint256 count = token.balanceOf(mintTo, tokenId);
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(address(this), address(0), mintTo, tokenIds, amounts);
        token.mint(mintTo, tokenIds, amounts, "");
        assertEq(count + amount, token.balanceOf(mintTo, tokenId));
    }

    // Minting allowed when token sale is free and global is not.
    function testFreeTokenMint(address mintTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(mintTo, tokenId, amount)
        withGlobalSaleActive
    {
        token.setTokenSalesDetails(tokenId, 0, uint64(block.timestamp - 1), uint64(block.timestamp + 1));
        uint256[] memory tokenIds = singleToArray(tokenId);
        uint256[] memory amounts = singleToArray(amount);

        uint256 count = token.balanceOf(mintTo, tokenId);
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(address(this), address(0), mintTo, tokenIds, amounts);
        token.mint(mintTo, tokenIds, amounts, "");
        assertEq(count + amount, token.balanceOf(mintTo, tokenId));
    }

    // Minting allowed when mint charged with ERC20.
    function testERC20Mint(address mintTo, uint256 tokenId, uint256 amount)
        public
        assumeSafe(mintTo, tokenId, amount)
        withERC20
    {
        token.setGlobalSalesDetails(
            address(erc20), perTokenCost, uint64(block.timestamp - 1), uint64(block.timestamp + 1)
        );
        uint256[] memory tokenIds = singleToArray(tokenId);
        uint256[] memory amounts = singleToArray(amount);
        uint256 cost = amount * perTokenCost;

        uint256 balanace = erc20.balanceOf(address(this));
        uint256 count = token.balanceOf(mintTo, tokenId);
        vm.expectEmit(true, true, true, true);
        emit TransferBatch(address(this), address(0), mintTo, tokenIds, amounts);
        token.mint(mintTo, tokenIds, amounts, "");
        assertEq(count + amount, token.balanceOf(mintTo, tokenId));
        assertEq(balanace - cost, erc20.balanceOf(address(this)));
        assertEq(cost, erc20.balanceOf(address(token)));
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
    // Helpers
    //
    modifier assumeSafe(address mintTo, uint256 tokenId, uint256 amount) {
        vm.assume(mintTo != address(0));
        vm.assume(mintTo.code.length == 0);
        vm.assume(tokenId < 100);
        vm.assume(amount > 0 && amount < 20);
        _;
    }

    // Create ERC20. Give this contract 100 ERC20 tokens. Approve token to spend 100 ERC20 tokens.
    modifier withERC20() {
        erc20 = new ERC20Mock();
        erc20.mockMint(address(this), 100 ether);
        erc20.approve(address(token), 100 ether);
        _;
    }

    modifier withGlobalSaleActive() {
        token.setGlobalSalesDetails(address(0), perTokenCost, uint64(block.timestamp - 1), uint64(block.timestamp + 1));
        _;
    }

    modifier withTokenSaleActive(uint256 tokenId) {
        setTokenSaleActive(tokenId);
        _;
    }

    function setTokenSaleActive(uint256 tokenId) private {
        token.setTokenSalesDetails(tokenId, perTokenCost, uint64(block.timestamp - 1), uint64(block.timestamp + 1));
    }

    function singleToArray(uint256 value) private pure returns (uint256[] memory) {
        uint256[] memory values = new uint256[](1);
        values[0] = value;
        return values;
    }
}
