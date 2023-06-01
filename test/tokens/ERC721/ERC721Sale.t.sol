// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import {ERC721Sale} from "src/tokens/ERC721/ERC721Sale.sol";
import {ERC721SaleFactory} from "src/tokens/ERC721/ERC721SaleFactory.sol";
import {ERC20Mock} from "@0xsequence/erc-1155/contracts/mocks/ERC20Mock.sol";
import {TWStrings} from "@thirdweb-dev/contracts/lib/TWStrings.sol";

contract ERC721SaleTest is Test {
    ERC721Sale private token;
    ERC20Mock private erc20;

    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address private admin;
    address private nftHolder;

    ERC721Sale.ClaimCondition condition;
    ERC721Sale.AllowlistProof allowlistProof;

    function setUp() public {
        admin = address(this);
        nftHolder = address(123);

        vm.deal(address(this), 100 ether);
        vm.deal(nftHolder, 100 ether);

        ERC721SaleFactory factory = new ERC721SaleFactory();
        address[] memory _trustedFowarders = new address[](0);
        token = ERC721Sale(
            factory.deployERC721Sale(address(this), "test", "test", _trustedFowarders, address(this), address(this), 0, "")
        );

        erc20 = new ERC20Mock();
    }

    //
    // Admin Minting
    //
    function testAdminMintingSuccess(address receiver, uint256 amount) external assumeSafe(receiver, amount) {
        token.adminClaim(receiver, amount);

        assertEq(token.balanceOf(receiver), amount);
        assertEq(token.totalSupply(), amount);
    }

    function testAdminMintingNonAdmin(address receiver, uint256 amount) external assumeSafe(receiver, amount) {
        vm.expectRevert(
            abi.encodePacked(
                "Permissions: account ",
                TWStrings.toHexString(uint160(receiver), 20),
                " is missing role ",
                TWStrings.toHexString(uint256(0), 32)
            )
        );
        vm.prank(receiver);
        token.adminClaim(receiver, amount);
    }

    function testAdminMintMaxSupply(address receiver, uint256 amount) external assumeSafe(receiver, 1) {
        vm.assume(amount > 1);
        vm.assume(amount < type(uint128).max - 1);
        token.setMaxTotalSupply(amount - 1);
        vm.expectRevert("exceed max total supply");
        token.adminClaim(receiver, amount);
    }

    //
    // Tests based on Third Web's ERC721Sale.t.sol
    //

    /**
     * note: Tests whether contract reverts when a non-holder renounces a role.
     */
    function test_revert_nonHolder_renounceRole() public {
        address caller = address(0x123);
        bytes32 role = keccak256("MINTER_ROLE");

        vm.prank(caller);
        vm.expectRevert(
            abi.encodePacked(
                "Permissions: account ",
                TWStrings.toHexString(uint160(caller), 20),
                " is missing role ",
                TWStrings.toHexString(uint256(role), 32)
            )
        );

        token.renounceRole(role, caller);
    }

    /**
     * note: Tests whether contract reverts when a role admin revokes a role for a non-holder.
     */
    function test_revert_revokeRoleForNonHolder() public {
        address target = address(0x123);
        bytes32 role = keccak256("MINTER_ROLE");

        vm.expectRevert(
            abi.encodePacked(
                "Permissions: account ",
                TWStrings.toHexString(uint160(target), 20),
                " is missing role ",
                TWStrings.toHexString(uint256(role), 32)
            )
        );

        token.revokeRole(role, target);
    }

    /**
     * @dev Tests whether role is granted.
     */
    function test_member_role_granted(address receiver) public {
        assumeEOA(receiver);

        bytes32 role = keccak256("ABC_ROLE");
        assertEq(token.hasRole(role, receiver), false);

        token.grantRole(role, receiver);

        assertEq(token.hasRole(role, receiver), true);
    }

    function test_claimCondition_with_startTimestamp(address receiver, address actor, address actor2) public {
        vm.assume(receiver != actor);
        vm.assume(actor != actor2);
        vm.assume(receiver != actor2);
        assumeEOA(receiver);
        assumeEOA(actor);
        assumeEOA(actor2);

        vm.warp(1);

        bytes32[] memory proofs = new bytes32[](0);

        ERC721Sale.AllowlistProof memory alp;
        alp.proof = proofs;

        ERC721Sale.ClaimCondition[] memory conditions = new ERC721Sale.ClaimCondition[](1);
        conditions[0].startTimestamp = 100;
        conditions[0].maxClaimableSupply = 100;
        conditions[0].quantityLimitPerWallet = 100;

        token.setClaimConditions(conditions, false);

        vm.warp(99);
        vm.prank(actor, actor);
        vm.expectRevert("!CONDITION.");
        token.claim(receiver, 1, address(0), 0, alp, "");

        vm.warp(100);
        vm.prank(actor2, actor2);
        token.claim(receiver, 1, address(0), 0, alp, "");
    }

    /**
     * note: Testing revert condition; not enough minted tokens.
     */
    function test_revert_claimCondition_notEnoughMintedTokens(address receiver, address actor) public {
        assumeEOA(receiver);
        assumeEOA(actor);

        vm.warp(1);

        bytes32[] memory proofs = new bytes32[](0);

        ERC721Sale.AllowlistProof memory alp;
        alp.proof = proofs;

        ERC721Sale.ClaimCondition[] memory conditions = new ERC721Sale.ClaimCondition[](1);
        conditions[0].maxClaimableSupply = 100;
        conditions[0].quantityLimitPerWallet = 200;

        token.setClaimConditions(conditions, false);

        vm.expectRevert("!MaxSupply");
        vm.prank(actor, actor);
        token.claim(receiver, 101, address(0), 0, alp, "");
    }

    /**
     * note: Testing revert condition; exceed max claimable supply.
     */
    function test_revert_claimCondition_exceedMaxClaimableSupply(address receiver, address actor, address actor2)
        public
    {
        vm.assume(actor != receiver);
        vm.assume(actor != actor2);
        assumeEOA(receiver);
        assumeEOA(actor);
        assumeEOA(actor2);

        vm.warp(1);

        bytes32[] memory proofs = new bytes32[](0);

        ERC721Sale.AllowlistProof memory alp;
        alp.proof = proofs;

        ERC721Sale.ClaimCondition[] memory conditions = new ERC721Sale.ClaimCondition[](1);
        conditions[0].maxClaimableSupply = 100;
        conditions[0].quantityLimitPerWallet = 200;

        token.setClaimConditions(conditions, false);

        vm.prank(actor, actor);
        token.claim(receiver, 100, address(0), 0, alp, "");

        vm.expectRevert("!MaxSupply");
        vm.prank(actor2, actor2);
        token.claim(receiver, 1, address(0), 0, alp, "");
    }

    /**
     * note: Testing quantity limit restriction when no allowlist present.
     */
    function test_fuzz_claim_noAllowlist(uint256 x, address receiver, address actor) public {
        vm.assume(x != 0);
        assumeEOA(receiver);
        assumeEOA(actor);

        vm.warp(1);

        bytes32[] memory proofs = new bytes32[](0);

        ERC721Sale.AllowlistProof memory alp;
        alp.proof = proofs;
        alp.quantityLimitPerWallet = x;

        ERC721Sale.ClaimCondition[] memory conditions = new ERC721Sale.ClaimCondition[](1);
        conditions[0].maxClaimableSupply = 500;
        conditions[0].quantityLimitPerWallet = 100;

        token.setClaimConditions(conditions, false);

        bytes memory errorQty = "!Qty";

        vm.prank(actor, actor);
        vm.expectRevert(errorQty);
        token.claim(receiver, 0, address(0), 0, alp, "");

        vm.prank(actor, actor);
        vm.expectRevert(errorQty);
        token.claim(receiver, 101, address(0), 0, alp, "");

        token.setClaimConditions(conditions, true);

        vm.prank(actor, actor);
        vm.expectRevert(errorQty);
        token.claim(receiver, 101, address(0), 0, alp, "");
    }

    /**
     * note: Testing quantity limit restriction
     * - allowlist quantity set to some value different than general limit
     * - allowlist price set to 0
     */
    function test_state_claim_allowlisted_SetQuantityZeroPrice() public {
        string[] memory inputs = new string[](5);

        inputs[0] = "node";
        inputs[1] = "test/scripts/generateRoot.ts";
        inputs[2] = "300";
        inputs[3] = "0";
        inputs[4] = TWStrings.toHexString(uint160(address(erc20))); // address of erc20

        bytes memory result = vm.ffi(inputs);
        // revert();
        bytes32 root = abi.decode(result, (bytes32));

        inputs[1] = "test/scripts/getProof.ts";
        result = vm.ffi(inputs);
        bytes32[] memory proofs = abi.decode(result, (bytes32[]));

        ERC721Sale.AllowlistProof memory alp;
        alp.proof = proofs;
        alp.quantityLimitPerWallet = 300;
        alp.pricePerToken = 0;
        alp.currency = address(erc20);

        vm.warp(1);

        address receiver = address(0x92Bb439374a091c7507bE100183d8D1Ed2c9dAD3); // in allowlist

        ERC721Sale.ClaimCondition[] memory conditions = new ERC721Sale.ClaimCondition[](1);
        conditions[0].maxClaimableSupply = 500;
        conditions[0].quantityLimitPerWallet = 10;
        conditions[0].merkleRoot = root;
        conditions[0].pricePerToken = 10;
        conditions[0].currency = address(erc20);

        token.setClaimConditions(conditions, false);

        vm.prank(receiver, receiver);
        token.claim(receiver, 100, address(erc20), 0, alp, ""); // claims for free, because allowlist price is 0
        assertEq(token.getSupplyClaimedByWallet(token.getActiveClaimConditionId(), receiver), 100);
    }

    /**
     * note: Testing quantity limit restriction
     * - allowlist quantity set to some value different than general limit
     * - allowlist price set to non-zero value
     */
    function test_state_claim_allowlisted_SetQuantityPrice() public {
        string[] memory inputs = new string[](5);

        inputs[0] = "node";
        inputs[1] = "test/scripts/generateRoot.ts";
        inputs[2] = "300";
        inputs[3] = "5";
        inputs[4] = TWStrings.toHexString(uint160(address(erc20))); // address of erc20

        bytes memory result = vm.ffi(inputs);
        // revert();
        bytes32 root = abi.decode(result, (bytes32));

        inputs[1] = "test/scripts/getProof.ts";
        result = vm.ffi(inputs);
        bytes32[] memory proofs = abi.decode(result, (bytes32[]));

        ERC721Sale.AllowlistProof memory alp;
        alp.proof = proofs;
        alp.quantityLimitPerWallet = 300;
        alp.pricePerToken = 5;
        alp.currency = address(erc20);

        vm.warp(1);

        address receiver = address(0x92Bb439374a091c7507bE100183d8D1Ed2c9dAD3); // in allowlist

        ERC721Sale.ClaimCondition[] memory conditions = new ERC721Sale.ClaimCondition[](1);
        conditions[0].maxClaimableSupply = 500;
        conditions[0].quantityLimitPerWallet = 10;
        conditions[0].merkleRoot = root;
        conditions[0].pricePerToken = 10;
        conditions[0].currency = address(erc20);

        token.setClaimConditions(conditions, false);

        vm.prank(receiver, receiver);
        vm.expectRevert("!PriceOrCurrency");
        token.claim(receiver, 100, address(erc20), 0, alp, "");

        erc20.mockMint(receiver, 10000);
        vm.prank(receiver);
        erc20.approve(address(token), 10000);

        vm.prank(receiver, receiver);
        token.claim(receiver, 100, address(erc20), 5, alp, "");
        assertEq(token.getSupplyClaimedByWallet(token.getActiveClaimConditionId(), receiver), 100);
        assertEq(erc20.balanceOf(receiver), 10000 - 500);
    }

    /**
     * note: Testing quantity limit restriction
     * - allowlist quantity set to some value different than general limit
     * - allowlist price not set; should default to general price and currency
     */
    function test_state_claim_allowlisted_SetQuantityDefaultPrice() public {
        string[] memory inputs = new string[](5);

        inputs[0] = "node";
        inputs[1] = "test/scripts/generateRoot.ts";
        inputs[2] = "300";
        inputs[3] = TWStrings.toString(type(uint256).max); // this implies that general price is applicable
        inputs[4] = "0x0000000000000000000000000000000000000000";

        bytes memory result = vm.ffi(inputs);
        // revert();
        bytes32 root = abi.decode(result, (bytes32));

        inputs[1] = "test/scripts/getProof.ts";
        result = vm.ffi(inputs);
        bytes32[] memory proofs = abi.decode(result, (bytes32[]));

        ERC721Sale.AllowlistProof memory alp;
        alp.proof = proofs;
        alp.quantityLimitPerWallet = 300;
        alp.pricePerToken = type(uint256).max;
        alp.currency = address(0);

        vm.warp(1);

        address receiver = address(0x92Bb439374a091c7507bE100183d8D1Ed2c9dAD3); // in allowlist

        ERC721Sale.ClaimCondition[] memory conditions = new ERC721Sale.ClaimCondition[](1);
        conditions[0].maxClaimableSupply = 500;
        conditions[0].quantityLimitPerWallet = 10;
        conditions[0].merkleRoot = root;
        conditions[0].pricePerToken = 10;
        conditions[0].currency = address(erc20);

        token.setClaimConditions(conditions, false);

        erc20.mockMint(receiver, 10000);
        vm.prank(receiver);
        erc20.approve(address(token), 10000);

        vm.prank(receiver, receiver);
        token.claim(receiver, 100, address(erc20), 10, alp, "");
        assertEq(token.getSupplyClaimedByWallet(token.getActiveClaimConditionId(), receiver), 100);
        assertEq(erc20.balanceOf(receiver), 10000 - 1000);
    }

    /**
     * note: Testing quantity limit restriction
     * - allowlist quantity set to 0 => should default to general limit
     * - allowlist price set to some value different than general price
     */
    function test_state_claim_allowlisted_DefaultQuantitySomePrice() public {
        string[] memory inputs = new string[](5);

        inputs[0] = "node";
        inputs[1] = "test/scripts/generateRoot.ts";
        inputs[2] = "0"; // this implies that general limit is applicable
        inputs[3] = "5";
        inputs[4] = "0x0000000000000000000000000000000000000000"; // general currency will be applicable

        bytes memory result = vm.ffi(inputs);
        // revert();
        bytes32 root = abi.decode(result, (bytes32));

        inputs[1] = "test/scripts/getProof.ts";
        result = vm.ffi(inputs);
        bytes32[] memory proofs = abi.decode(result, (bytes32[]));

        ERC721Sale.AllowlistProof memory alp;
        alp.proof = proofs;
        alp.quantityLimitPerWallet = 0;
        alp.pricePerToken = 5;
        alp.currency = address(0);

        vm.warp(1);

        address receiver = address(0x92Bb439374a091c7507bE100183d8D1Ed2c9dAD3); // in allowlist

        ERC721Sale.ClaimCondition[] memory conditions = new ERC721Sale.ClaimCondition[](1);
        conditions[0].maxClaimableSupply = 500;
        conditions[0].quantityLimitPerWallet = 10;
        conditions[0].merkleRoot = root;
        conditions[0].pricePerToken = 10;
        conditions[0].currency = address(erc20);

        token.setClaimConditions(conditions, false);

        erc20.mockMint(receiver, 10000);
        vm.prank(receiver);
        erc20.approve(address(token), 10000);

        bytes memory errorQty = "!Qty";
        vm.prank(receiver, receiver);
        vm.expectRevert(errorQty);
        token.claim(receiver, 100, address(erc20), 5, alp, ""); // trying to claim more than general limit

        vm.prank(receiver, receiver);
        token.claim(receiver, 10, address(erc20), 5, alp, "");
        assertEq(token.getSupplyClaimedByWallet(token.getActiveClaimConditionId(), receiver), 10);
        assertEq(erc20.balanceOf(receiver), 10000 - 50);
    }

    function test_fuzz_claim_merkleProof(uint256 x) public {
        vm.assume(x > 10 && x < 500);

        string[] memory inputs = new string[](5);

        inputs[0] = "node";
        inputs[1] = "test/scripts/generateRoot.ts";
        inputs[2] = TWStrings.toString(x);
        inputs[3] = "0";
        inputs[4] = "0x0000000000000000000000000000000000000000";

        bytes memory result = vm.ffi(inputs);
        // revert();
        bytes32 root = abi.decode(result, (bytes32));

        inputs[1] = "test/scripts/getProof.ts";
        result = vm.ffi(inputs);
        bytes32[] memory proofs = abi.decode(result, (bytes32[]));

        ERC721Sale.AllowlistProof memory alp;
        alp.proof = proofs;
        alp.quantityLimitPerWallet = x;
        alp.pricePerToken = 0;
        alp.currency = address(0);

        vm.warp(1);

        address receiver = address(0x92Bb439374a091c7507bE100183d8D1Ed2c9dAD3);

        // bytes32[] memory proofs = new bytes32[](0);

        ERC721Sale.ClaimCondition[] memory conditions = new ERC721Sale.ClaimCondition[](1);
        conditions[0].maxClaimableSupply = x;
        conditions[0].quantityLimitPerWallet = 1;
        conditions[0].merkleRoot = root;

        token.setClaimConditions(conditions, false);

        vm.prank(receiver, receiver);
        token.claim(receiver, x - 5, address(0), 0, alp, "");
        assertEq(token.getSupplyClaimedByWallet(token.getActiveClaimConditionId(), receiver), x - 5);

        bytes memory errorQty = "!Qty";

        vm.prank(receiver, receiver);
        vm.expectRevert(errorQty);
        token.claim(receiver, 6, address(0), 0, alp, "");

        vm.prank(receiver, receiver);
        token.claim(receiver, 5, address(0), 0, alp, "");
        assertEq(token.getSupplyClaimedByWallet(token.getActiveClaimConditionId(), receiver), x);

        vm.prank(receiver, receiver);
        vm.expectRevert(errorQty);
        token.claim(receiver, 5, address(0), 0, alp, ""); // quantity limit already claimed
    }

    /**
     * note: Testing state changes; reset eligibility of claim conditions and claiming again for same condition id.
     */
    function test_state_claimCondition_resetEligibility(address receiver, address actor) public {
        assumeEOA(receiver);
        assumeEOA(actor);

        vm.warp(1);

        bytes32[] memory proofs = new bytes32[](0);

        ERC721Sale.AllowlistProof memory alp;
        alp.proof = proofs;

        ERC721Sale.ClaimCondition[] memory conditions = new ERC721Sale.ClaimCondition[](1);
        conditions[0].maxClaimableSupply = 500;
        conditions[0].quantityLimitPerWallet = 100;

        token.setClaimConditions(conditions, false);

        vm.prank(actor, actor);
        token.claim(receiver, 100, address(0), 0, alp, "");

        bytes memory errorQty = "!Qty";

        vm.prank(actor, actor);
        vm.expectRevert(errorQty);
        token.claim(receiver, 100, address(0), 0, alp, "");

        token.setClaimConditions(conditions, true);

        vm.prank(actor, actor);
        token.claim(receiver, 100, address(0), 0, alp, "");
    }

    function test_claimCondition_startIdAndCount() public {
        uint256 currentStartId = 0;
        uint256 count = 0;

        ERC721Sale.ClaimCondition[] memory conditions = new ERC721Sale.ClaimCondition[](2);
        conditions[0].startTimestamp = 0;
        conditions[0].maxClaimableSupply = 10;
        conditions[1].startTimestamp = 1;
        conditions[1].maxClaimableSupply = 10;

        token.setClaimConditions(conditions, false);
        (currentStartId, count) = token.claimCondition();
        assertEq(currentStartId, 0);
        assertEq(count, 2);

        token.setClaimConditions(conditions, false);
        (currentStartId, count) = token.claimCondition();
        assertEq(currentStartId, 0);
        assertEq(count, 2);

        token.setClaimConditions(conditions, true);
        (currentStartId, count) = token.claimCondition();
        assertEq(currentStartId, 2);
        assertEq(count, 2);

        token.setClaimConditions(conditions, true);
        (currentStartId, count) = token.claimCondition();
        assertEq(currentStartId, 4);
        assertEq(count, 2);
    }

    function test_claimCondition_startPhase() public {
        uint256 activeConditionId = 0;

        ERC721Sale.ClaimCondition[] memory conditions = new ERC721Sale.ClaimCondition[](3);
        conditions[0].startTimestamp = 10;
        conditions[0].maxClaimableSupply = 11;
        conditions[0].quantityLimitPerWallet = 12;
        conditions[1].startTimestamp = 20;
        conditions[1].maxClaimableSupply = 21;
        conditions[1].quantityLimitPerWallet = 22;
        conditions[2].startTimestamp = 30;
        conditions[2].maxClaimableSupply = 31;
        conditions[2].quantityLimitPerWallet = 32;
        token.setClaimConditions(conditions, false);

        vm.expectRevert("!CONDITION.");
        token.getActiveClaimConditionId();

        vm.warp(10);
        activeConditionId = token.getActiveClaimConditionId();
        assertEq(activeConditionId, 0);
        assertEq(token.getClaimConditionById(activeConditionId).startTimestamp, 10);
        assertEq(token.getClaimConditionById(activeConditionId).maxClaimableSupply, 11);
        assertEq(token.getClaimConditionById(activeConditionId).quantityLimitPerWallet, 12);

        vm.warp(20);
        activeConditionId = token.getActiveClaimConditionId();
        assertEq(activeConditionId, 1);
        assertEq(token.getClaimConditionById(activeConditionId).startTimestamp, 20);
        assertEq(token.getClaimConditionById(activeConditionId).maxClaimableSupply, 21);
        assertEq(token.getClaimConditionById(activeConditionId).quantityLimitPerWallet, 22);

        vm.warp(30);
        activeConditionId = token.getActiveClaimConditionId();
        assertEq(activeConditionId, 2);
        assertEq(token.getClaimConditionById(activeConditionId).startTimestamp, 30);
        assertEq(token.getClaimConditionById(activeConditionId).maxClaimableSupply, 31);
        assertEq(token.getClaimConditionById(activeConditionId).quantityLimitPerWallet, 32);

        vm.warp(40);
        assertEq(token.getActiveClaimConditionId(), 2);
    }

    //
    // Helpers
    //
    modifier assumeSafe(address eoa, uint256 amount) {
        assumeEOA(eoa);
        vm.assume(amount > 0 && amount < 20);
        _;
    }

    function assumeEOA(address eoa) private {
        vm.assume(uint160(eoa) > 16);
        vm.assume(eoa.code.length == 0);
    }
}
