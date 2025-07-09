// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { TestHelper } from "../../../../TestHelper.sol";
import { ERC20Mock } from "../../../../_mocks/ERC20Mock.sol";

import { IERC1155SupplySignals } from "src/tokens/ERC1155/extensions/supply/IERC1155Supply.sol";
import { ERC1155Items } from "src/tokens/ERC1155/presets/items/ERC1155Items.sol";
import { ERC1155Sale } from "src/tokens/ERC1155/utility/sale/ERC1155Sale.sol";
import { ERC1155SaleFactory } from "src/tokens/ERC1155/utility/sale/ERC1155SaleFactory.sol";
import { IERC1155SaleSignals } from "src/tokens/ERC1155/utility/sale/IERC1155Sale.sol";
import { IMerkleProofSingleUseSignals } from "src/tokens/common/IMerkleProofSingleUse.sol";

// solhint-disable not-rely-on-time

contract ERC1155SaleMintTest is TestHelper, IERC1155SaleSignals, IERC1155SupplySignals, IMerkleProofSingleUseSignals {

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

    //
    // Minting
    //

    // Minting denied when no sale active.
    function testMintInactiveFail(
        bool useFactory,
        address mintTo,
        uint256 tokenId,
        uint256 amount
    ) public withFactory(useFactory) {
        (tokenId, amount) = assumeSafe(mintTo, tokenId, amount);
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256 cost = amount * perTokenCost;

        vm.expectRevert(abi.encodeWithSelector(SaleInactive.selector, tokenId));
        sale.mint{ value: cost }(mintTo, tokenIds, amounts, "", address(0), cost, TestHelper.blankProof());
    }

    // Minting denied when sale is active but not for the token.
    function testMintInactiveSingleFail(
        bool useFactory,
        address mintTo,
        uint256 tokenId,
        uint256 amount
    ) public withFactory(useFactory) {
        (tokenId, amount) = assumeSafe(mintTo, tokenId, amount);
        setTokenSaleActive(tokenId + 1);
        uint256 cost = amount * perTokenCost;

        vm.expectRevert(abi.encodeWithSelector(SaleInactive.selector, tokenId));
        sale.mint{ value: cost }(
            mintTo,
            TestHelper.singleToArray(tokenId),
            TestHelper.singleToArray(amount),
            "",
            address(0),
            cost,
            TestHelper.blankProof()
        );
    }

    // Minting denied when token sale is expired.
    function testMintExpiredSingleFail(
        bool useFactory,
        address mintTo,
        uint256 tokenId,
        uint256 amount,
        uint64 startTime,
        uint64 endTime
    ) public withFactory(useFactory) {
        startTime = uint64(bound(startTime, 0, type(uint64).max - 1));
        endTime = uint64(bound(endTime, 0, type(uint64).max - 1));

        (tokenId, amount) = assumeSafe(mintTo, tokenId, amount);
        if (startTime > endTime) {
            uint64 temp = startTime;
            startTime = endTime;
            endTime = temp;
        }
        if (endTime == 0) {
            endTime++;
        }

        vm.warp(uint256(endTime) - 1);
        sale.setTokenSaleDetails(tokenId, perTokenCost, amount, startTime, endTime, "");
        vm.warp(uint256(endTime) + 1);

        uint256 cost = amount * perTokenCost;

        vm.expectRevert(abi.encodeWithSelector(SaleInactive.selector, tokenId));
        sale.mint{ value: cost }(
            mintTo,
            TestHelper.singleToArray(tokenId),
            TestHelper.singleToArray(amount),
            "",
            address(0),
            cost,
            TestHelper.blankProof()
        );
    }

    // Minting denied when global sale is expired.
    function testMintExpiredGlobalFail(
        bool useFactory,
        address mintTo,
        uint256 tokenId,
        uint256 amount,
        uint64 startTime,
        uint64 endTime
    ) public withFactory(useFactory) {
        startTime = uint64(bound(startTime, 0, type(uint64).max - 1));
        endTime = uint64(bound(endTime, 0, type(uint64).max - 1));

        (tokenId, amount) = assumeSafe(mintTo, tokenId, amount);
        if (startTime > endTime) {
            uint64 temp = startTime;
            startTime = endTime;
            endTime = temp;
        }
        if (endTime == 0) {
            endTime++;
        }

        vm.warp(uint256(endTime) - 1);
        sale.setGlobalSaleDetails(0, type(uint256).max, perTokenCost, amount, startTime, endTime, "");
        vm.warp(uint256(endTime) + 1);

        uint256 cost = amount * perTokenCost;

        vm.expectRevert(abi.encodeWithSelector(SaleInactive.selector, tokenId));
        sale.mint{ value: cost }(
            mintTo,
            TestHelper.singleToArray(tokenId),
            TestHelper.singleToArray(amount),
            "",
            address(0),
            cost,
            TestHelper.blankProof()
        );
    }

    // Minting denied when sale is active but not for all tokens in the group.
    function testMintInactiveInGroupFail(
        bool useFactory,
        address mintTo,
        uint256 tokenId,
        uint256 amount
    ) public withFactory(useFactory) {
        (tokenId, amount) = assumeSafe(mintTo, tokenId, amount);
        setTokenSaleActive(tokenId);
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId;
        tokenIds[1] = tokenId + 1;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount;
        amounts[1] = amount;
        uint256 cost = amount * perTokenCost * 2;

        vm.expectRevert(abi.encodeWithSelector(SaleInactive.selector, tokenId + 1));
        sale.mint{ value: cost }(mintTo, tokenIds, amounts, "", address(0), cost, TestHelper.blankProof());
    }

    // Minting denied when global supply exceeded.
    function testMintGlobalSupplyExceeded(
        bool useFactory,
        address mintTo,
        uint256 tokenId,
        uint256 amount,
        uint256 remainingSupply
    ) public withFactory(useFactory) {
        (tokenId, amount) = assumeSafe(mintTo, tokenId, amount);
        amount = bound(amount, 2, 20);
        remainingSupply = bound(remainingSupply, 1, amount - 1);
        sale.setGlobalSaleDetails(
            0,
            type(uint256).max,
            perTokenCost,
            remainingSupply,
            uint64(block.timestamp),
            uint64(block.timestamp + 1),
            ""
        );

        uint256 cost = amount * perTokenCost;

        vm.expectRevert(abi.encodeWithSelector(InsufficientSupply.selector, remainingSupply, amount));
        sale.mint{ value: cost }(
            mintTo,
            TestHelper.singleToArray(tokenId),
            TestHelper.singleToArray(amount),
            "",
            address(0),
            cost,
            TestHelper.blankProof()
        );
    }

    // Minting denied when token supply exceeded.
    function testMintTokenSupplyExceeded(
        bool useFactory,
        address mintTo,
        uint256 tokenId,
        uint256 amount,
        uint256 remainingSupply
    ) public withFactory(useFactory) {
        (tokenId, amount) = assumeSafe(mintTo, tokenId, amount);
        amount = bound(amount, 2, 20);
        remainingSupply = bound(remainingSupply, 1, amount - 1);
        sale.setTokenSaleDetails(
            tokenId, perTokenCost, remainingSupply, uint64(block.timestamp), uint64(block.timestamp + 1), ""
        );

        uint256 cost = amount * perTokenCost;

        vm.expectRevert(abi.encodeWithSelector(InsufficientSupply.selector, remainingSupply, amount));
        sale.mint{ value: cost }(
            mintTo,
            TestHelper.singleToArray(tokenId),
            TestHelper.singleToArray(amount),
            "",
            address(0),
            cost,
            TestHelper.blankProof()
        );
    }

    // Minting allowed when sale is active globally.
    function testMintGlobalSuccess(
        bool useFactory,
        address mintTo,
        uint256 tokenId,
        uint256 amount
    ) public withFactory(useFactory) withGlobalSaleActive {
        (tokenId, amount) = assumeSafe(mintTo, tokenId, amount);
        uint256 cost = amount * perTokenCost;

        uint256 count = token.balanceOf(mintTo, tokenId);
        {
            uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
            uint256[] memory amounts = TestHelper.singleToArray(amount);
            vm.expectEmit(true, true, true, true, address(token));
            emit TransferBatch(address(sale), address(0), mintTo, tokenIds, amounts);
            vm.expectEmit(true, true, true, true, address(sale));
            emit ItemsMinted(mintTo, tokenIds, amounts);
            sale.mint{ value: cost }(mintTo, tokenIds, amounts, "", address(0), cost, TestHelper.blankProof());
        }
        assertEq(count + amount, token.balanceOf(mintTo, tokenId));
    }

    // Minting allowed when sale is active for the token.
    function testMintSingleSuccess(
        bool useFactory,
        address mintTo,
        uint256 tokenId,
        uint256 amount
    ) public withFactory(useFactory) {
        (tokenId, amount) = assumeSafe(mintTo, tokenId, amount);
        setTokenSaleActive(tokenId);
        uint256 cost = amount * perTokenCost;

        uint256 count = token.balanceOf(mintTo, tokenId);
        {
            uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
            uint256[] memory amounts = TestHelper.singleToArray(amount);
            vm.expectEmit(true, true, true, true, address(token));
            emit TransferBatch(address(sale), address(0), mintTo, tokenIds, amounts);
            vm.expectEmit(true, true, true, true, address(sale));
            emit ItemsMinted(mintTo, tokenIds, amounts);
            sale.mint{ value: cost }(mintTo, tokenIds, amounts, "", address(0), cost, TestHelper.blankProof());
        }
        assertEq(count + amount, token.balanceOf(mintTo, tokenId));
    }

    // Minting allowed when sale is active for both tokens individually.
    function testMintGroupSuccess(
        bool useFactory,
        address mintTo,
        uint256 tokenId,
        uint256 amount
    ) public withFactory(useFactory) {
        (tokenId, amount) = assumeSafe(mintTo, tokenId, amount);
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
        vm.expectEmit(true, true, true, true, address(sale));
        emit ItemsMinted(mintTo, tokenIds, amounts);
        sale.mint{ value: cost }(mintTo, tokenIds, amounts, "", address(0), cost, TestHelper.blankProof());
        assertEq(count + amount, token.balanceOf(mintTo, tokenId));
        assertEq(count2 + amount, token.balanceOf(mintTo, tokenId + 1));
    }

    // Minting allowed when global sale is free.
    function testFreeGlobalMint(
        bool useFactory,
        address mintTo,
        uint256 tokenId,
        uint256 amount
    ) public withFactory(useFactory) {
        (tokenId, amount) = assumeSafe(mintTo, tokenId, amount);
        sale.setGlobalSaleDetails(
            0, type(uint256).max, 0, type(uint256).max, uint64(block.timestamp - 1), uint64(block.timestamp + 1), ""
        );
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);

        uint256 count = token.balanceOf(mintTo, tokenId);
        vm.expectEmit(true, true, true, true, address(token));
        emit TransferBatch(address(sale), address(0), mintTo, tokenIds, amounts);
        vm.expectEmit(true, true, true, true, address(sale));
        emit ItemsMinted(mintTo, tokenIds, amounts);
        sale.mint(mintTo, tokenIds, amounts, "", address(0), 0, TestHelper.blankProof());
        assertEq(count + amount, token.balanceOf(mintTo, tokenId));
    }

    // Minting allowed when token sale is free and global is not.
    function testFreeTokenMint(
        bool useFactory,
        address mintTo,
        uint256 tokenId,
        uint256 amount
    ) public withFactory(useFactory) withGlobalSaleActive {
        (tokenId, amount) = assumeSafe(mintTo, tokenId, amount);
        sale.setTokenSaleDetails(
            tokenId, 0, type(uint256).max, uint64(block.timestamp - 1), uint64(block.timestamp + 1), ""
        );
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);

        uint256 count = token.balanceOf(mintTo, tokenId);
        vm.expectEmit(true, true, true, true, address(token));
        emit TransferBatch(address(sale), address(0), mintTo, tokenIds, amounts);
        vm.expectEmit(true, true, true, true, address(sale));
        emit ItemsMinted(mintTo, tokenIds, amounts);
        sale.mint(mintTo, tokenIds, amounts, "", address(0), 0, TestHelper.blankProof());
        assertEq(count + amount, token.balanceOf(mintTo, tokenId));
    }

    // Minting allowed when mint charged with ERC20.
    function testERC20Mint(
        bool useFactory,
        address mintTo,
        uint256 tokenId,
        uint256 amount
    ) public withFactory(useFactory) withERC20 {
        (tokenId, amount) = assumeSafe(mintTo, tokenId, amount);
        sale.setPaymentToken(address(erc20));
        sale.setGlobalSaleDetails(
            0,
            type(uint256).max,
            perTokenCost,
            type(uint256).max,
            uint64(block.timestamp - 1),
            uint64(block.timestamp + 1),
            ""
        );
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256 cost = amount * perTokenCost;

        uint256 balance = erc20.balanceOf(address(this));
        uint256 count = token.balanceOf(mintTo, tokenId);
        vm.expectEmit(true, true, true, true, address(token));
        emit TransferBatch(address(sale), address(0), mintTo, tokenIds, amounts);
        vm.expectEmit(true, true, true, true, address(sale));
        emit ItemsMinted(mintTo, tokenIds, amounts);
        sale.mint(mintTo, tokenIds, amounts, "", address(erc20), cost, TestHelper.blankProof());
        assertEq(count + amount, token.balanceOf(mintTo, tokenId));
        assertEq(balance - cost, erc20.balanceOf(address(this)));
        assertEq(cost, erc20.balanceOf(address(sale)));
    }

    // Minting with merkle success.
    function testMerkleSuccess(
        address[] memory allowlist,
        uint256 senderIndex,
        uint256 tokenId,
        bool globalActive
    ) public returns (address sender, bytes32 root, bytes32[] memory proof) {
        // Construct a merkle tree with the allowlist.
        vm.assume(allowlist.length > 1);
        senderIndex = bound(senderIndex, 0, allowlist.length - 1);
        sender = allowlist[senderIndex];
        assumeSafeAddress(sender);

        uint256 salt = globalActive ? type(uint256).max : tokenId;
        (root, proof) = TestHelper.getMerkleParts(allowlist, salt, senderIndex);

        if (globalActive) {
            sale.setGlobalSaleDetails(
                0,
                type(uint256).max,
                0,
                type(uint256).max,
                uint64(block.timestamp - 1),
                uint64(block.timestamp + 1),
                root
            );
        } else {
            sale.setTokenSaleDetails(
                tokenId, 0, type(uint256).max, uint64(block.timestamp - 1), uint64(block.timestamp + 1), root
            );
        }

        vm.expectEmit(true, true, true, true, address(sale));
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(uint256(1));
        emit ItemsMinted(sender, tokenIds, amounts);
        vm.prank(sender);
        sale.mint(sender, tokenIds, amounts, "", address(0), 0, proof);

        assertEq(1, token.balanceOf(sender, tokenId));
    }

    // Minting with merkle success.
    function testMerkleSuccessGlobalMultiple(
        address[] memory allowlist,
        uint256 senderIndex,
        uint256[] memory tokenIds
    ) public {
        uint256 tokenIdLen = tokenIds.length;
        vm.assume(tokenIdLen > 1);
        vm.assume(tokenIds[0] != tokenIds[1]);
        if (tokenIds[0] > tokenIds[1]) {
            // Must be ordered
            (tokenIds[1], tokenIds[0]) = (tokenIds[0], tokenIds[1]);
        }

        // solhint-disable-next-line no-inline-assembly
        assembly {
            mstore(tokenIds, 2) // Exactly 2 unique tokenIds
        }
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 1;

        // Construct a merkle tree with the allowlist.
        vm.assume(allowlist.length > 1);
        senderIndex = bound(senderIndex, 0, allowlist.length - 1);
        address sender = allowlist[senderIndex];
        assumeSafeAddress(sender);

        (bytes32 root, bytes32[] memory proof) = TestHelper.getMerkleParts(allowlist, type(uint256).max, senderIndex);

        sale.setGlobalSaleDetails(
            0, type(uint256).max, 0, type(uint256).max, uint64(block.timestamp - 1), uint64(block.timestamp + 1), root
        );

        vm.expectEmit(true, true, true, true, address(sale));
        emit ItemsMinted(sender, tokenIds, amounts);
        vm.prank(sender);
        sale.mint(sender, tokenIds, amounts, "", address(0), 0, proof);

        assertEq(1, token.balanceOf(sender, tokenIds[0]));
        assertEq(1, token.balanceOf(sender, tokenIds[1]));
    }

    // Minting with merkle reuse fail.
    function testMerkleReuseFail(
        address[] memory allowlist,
        uint256 senderIndex,
        uint256 tokenId,
        bool globalActive
    ) public {
        (address sender, bytes32 root, bytes32[] memory proof) =
            testMerkleSuccess(allowlist, senderIndex, tokenId, globalActive);

        {
            vm.expectRevert(
                abi.encodeWithSelector(
                    MerkleProofInvalid.selector, root, proof, sender, globalActive ? type(uint256).max : tokenId
                )
            );
            vm.prank(sender);
            sale.mint(
                sender,
                TestHelper.singleToArray(tokenId),
                TestHelper.singleToArray(uint256(1)),
                "",
                address(0),
                0,
                proof
            );
        }
    }

    // Minting with merkle fail no proof.
    function testMerkleFailNoProof(
        address[] memory allowlist,
        address sender,
        uint256 tokenId,
        bool globalActive
    ) public {
        // Construct a merkle tree with the allowlist.
        vm.assume(allowlist.length > 1);

        uint256 salt = globalActive ? type(uint256).max : tokenId;
        (bytes32 root,) = TestHelper.getMerkleParts(allowlist, salt, 0);
        bytes32[] memory proof = TestHelper.blankProof();

        if (globalActive) {
            sale.setGlobalSaleDetails(
                0,
                type(uint256).max,
                0,
                type(uint256).max,
                uint64(block.timestamp - 1),
                uint64(block.timestamp + 1),
                root
            );
        } else {
            sale.setTokenSaleDetails(
                tokenId, 0, type(uint256).max, uint64(block.timestamp - 1), uint64(block.timestamp + 1), root
            );
        }

        vm.expectRevert(abi.encodeWithSelector(MerkleProofInvalid.selector, root, proof, sender, salt));
        vm.prank(sender);
        sale.mint(
            sender, TestHelper.singleToArray(tokenId), TestHelper.singleToArray(uint256(1)), "", address(0), 0, proof
        );
    }

    // Minting with merkle fail bad proof.
    function testMerkleFailBadProof(
        address[] memory allowlist,
        address sender,
        uint256 tokenId,
        bool globalActive
    ) public {
        // Construct a merkle tree with the allowlist.
        vm.assume(allowlist.length > 1);
        vm.assume(allowlist[1] != sender);

        uint256 salt = globalActive ? type(uint256).max : tokenId;
        (bytes32 root, bytes32[] memory proof) = TestHelper.getMerkleParts(allowlist, salt, 1); // Wrong sender

        if (globalActive) {
            sale.setGlobalSaleDetails(
                0,
                type(uint256).max,
                0,
                type(uint256).max,
                uint64(block.timestamp - 1),
                uint64(block.timestamp + 1),
                root
            );
        } else {
            sale.setTokenSaleDetails(
                tokenId, 0, type(uint256).max, uint64(block.timestamp - 1), uint64(block.timestamp + 1), root
            );
        }

        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(uint256(1));

        vm.expectRevert(abi.encodeWithSelector(MerkleProofInvalid.selector, root, proof, sender, salt));
        vm.prank(sender);
        sale.mint(sender, tokenIds, amounts, "", address(0), 0, proof);
    }

    function testGlobalMintFailOutOfRange(
        bool useFactory,
        address mintTo,
        uint256 tokenId,
        uint256 amount,
        bool tokenIsUnder, // Or over
        uint256 minTokenId,
        uint256 maxTokenId
    ) public withFactory(useFactory) {
        (tokenId, amount) = assumeSafe(mintTo, tokenId, amount);
        tokenId = bound(tokenId, 1, type(uint256).max - 1);
        if (tokenIsUnder) {
            minTokenId = bound(minTokenId, tokenId + 1, type(uint256).max);
            maxTokenId = bound(maxTokenId, minTokenId, type(uint256).max);
        } else {
            maxTokenId = bound(maxTokenId, 0, tokenId - 1);
            minTokenId = bound(minTokenId, 0, maxTokenId);
        }
        sale.setGlobalSaleDetails(
            minTokenId, maxTokenId, 0, type(uint256).max, uint64(block.timestamp - 1), uint64(block.timestamp + 1), ""
        );
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);

        vm.expectRevert(abi.encodeWithSelector(SaleInactive.selector, tokenId));
        sale.mint(mintTo, tokenIds, amounts, "", address(0), 0, TestHelper.blankProof());
    }

    // Minting fails with invalid maxTotal.
    function testMintFailMaxTotal(
        bool useFactory,
        address mintTo,
        uint256 tokenId,
        uint256 amount
    ) public withFactory(useFactory) withGlobalSaleActive {
        (tokenId, amount) = assumeSafe(mintTo, tokenId, amount);
        uint256[] memory tokenIds = TestHelper.singleToArray(tokenId);
        uint256[] memory amounts = TestHelper.singleToArray(amount);
        uint256 cost = amount * perTokenCost;

        bytes memory err = abi.encodeWithSelector(InsufficientPayment.selector, address(0), cost, cost - 1);

        vm.expectRevert(err);
        sale.mint{ value: cost }(mintTo, tokenIds, amounts, "", address(0), cost - 1, TestHelper.blankProof());

        sale.setTokenSaleDetails(
            tokenId, perTokenCost, type(uint256).max, uint64(block.timestamp - 1), uint64(block.timestamp + 1), ""
        );
        vm.expectRevert(err);
        sale.mint{ value: cost }(mintTo, tokenIds, amounts, "", address(0), cost - 1, TestHelper.blankProof());

        sale.setPaymentToken(address(erc20));
        sale.setGlobalSaleDetails(
            0,
            type(uint256).max,
            perTokenCost,
            type(uint256).max,
            uint64(block.timestamp - 1),
            uint64(block.timestamp + 1),
            ""
        );
        vm.expectRevert(err);
        sale.mint(mintTo, tokenIds, amounts, "", address(erc20), cost - 1, TestHelper.blankProof());
    }

    // Minting fails with invalid payment token.
    function testMintFailWrongPaymentToken(
        bool useFactory,
        address mintTo,
        uint256 tokenId,
        uint256 amount,
        address wrongToken
    ) public withFactory(useFactory) withERC20 {
        (tokenId, amount) = assumeSafe(mintTo, tokenId, amount);
        address paymentToken = wrongToken == address(0) ? address(erc20) : address(0);
        sale.setPaymentToken(paymentToken);
        sale.setGlobalSaleDetails(
            0, type(uint256).max, 0, type(uint256).max, uint64(block.timestamp - 1), uint64(block.timestamp + 1), ""
        );

        bytes memory err = abi.encodeWithSelector(InsufficientPayment.selector, paymentToken, 0, 0);
        vm.expectRevert(err);
        sale.mint(
            mintTo,
            TestHelper.singleToArray(tokenId),
            TestHelper.singleToArray(amount),
            "",
            wrongToken,
            0,
            TestHelper.blankProof()
        );

        sale.setTokenSaleDetails(
            tokenId, 0, type(uint256).max, uint64(block.timestamp - 1), uint64(block.timestamp + 1), ""
        );

        vm.expectRevert(err);
        sale.mint(
            mintTo,
            TestHelper.singleToArray(tokenId),
            TestHelper.singleToArray(amount),
            "",
            wrongToken,
            0,
            TestHelper.blankProof()
        );
    }

    // Minting fails with invalid payment token.
    function testERC20MintFailPaidETH(
        bool useFactory,
        address mintTo,
        uint256 tokenId,
        uint256 amount
    ) public withFactory(useFactory) withERC20 {
        (tokenId, amount) = assumeSafe(mintTo, tokenId, amount);
        sale.setPaymentToken(address(erc20));
        sale.setGlobalSaleDetails(
            0, type(uint256).max, 0, type(uint256).max, uint64(block.timestamp - 1), uint64(block.timestamp + 1), ""
        );

        bytes memory err = abi.encodeWithSelector(InsufficientPayment.selector, address(0), 0, 1);
        vm.expectRevert(err);
        sale.mint{ value: 1 }(
            mintTo,
            TestHelper.singleToArray(tokenId),
            TestHelper.singleToArray(amount),
            "",
            address(erc20),
            0,
            TestHelper.blankProof()
        );

        sale.setTokenSaleDetails(
            tokenId, 0, type(uint256).max, uint64(block.timestamp - 1), uint64(block.timestamp + 1), ""
        );

        vm.expectRevert(err);
        sale.mint{ value: 1 }(
            mintTo,
            TestHelper.singleToArray(tokenId),
            TestHelper.singleToArray(amount),
            "",
            address(erc20),
            0,
            TestHelper.blankProof()
        );
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

    function assumeSafe(
        address nonContract,
        uint256 tokenId,
        uint256 amount
    ) private view returns (uint256 boundTokenId, uint256 boundAmount) {
        assumeSafeAddress(nonContract);
        vm.assume(nonContract != proxyOwner);
        tokenId = bound(tokenId, 0, 100);
        amount = bound(amount, 1, 19);
        return (tokenId, amount);
    }

    // Create ERC20. Give this contract 1000 ERC20 tokens. Approve token to spend 100 ERC20 tokens.
    modifier withERC20() {
        erc20 = new ERC20Mock(address(this));
        erc20.mint(address(this), 1000 ether);
        erc20.approve(address(sale), 1000 ether);
        _;
    }

    modifier withGlobalSaleActive() {
        sale.setGlobalSaleDetails(
            0,
            type(uint256).max,
            perTokenCost,
            type(uint256).max,
            uint64(block.timestamp - 1),
            uint64(block.timestamp + 1),
            ""
        );
        _;
    }

    function setTokenSaleActive(
        uint256 tokenId
    ) private {
        sale.setTokenSaleDetails(
            tokenId, perTokenCost, type(uint256).max, uint64(block.timestamp - 1), uint64(block.timestamp + 1), ""
        );
    }

}
