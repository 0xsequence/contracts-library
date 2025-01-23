// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {TestHelper} from "../../../TestHelper.sol";
import {LootboxReentryMock} from "../../../_mocks/LootboxReentryMock.sol";
import {ERC1155Items} from "src/tokens/ERC1155/presets/items/ERC1155Items.sol";
import {ERC1155Lootbox} from "src/tokens/ERC1155/presets/lootbox/ERC1155Lootbox.sol";
import {IERC1155ItemsSignals, IERC1155ItemsFunctions} from "src/tokens/ERC1155/presets/items/IERC1155Items.sol";
import {
    IERC1155LootboxSignals,
    IERC1155LootboxFunctions,
    IERC1155Lootbox
} from "src/tokens/ERC1155/presets/lootbox/IERC1155Lootbox.sol";
import {ERC1155LootboxFactory} from "src/tokens/ERC1155/presets/lootbox/ERC1155LootboxFactory.sol";

// Interfaces
import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract ERC1155LootboxHack is ERC1155Lootbox {
    function setAllExceptOneClaimed(uint256 _idx) public {
        remainingSupply = 1;
        // Update _availableIndices to point to the last index
        _availableIndices[0] = _idx;
    }
}

contract ERC1155LootboxTest is TestHelper, IERC1155ItemsSignals, IERC1155LootboxSignals {
    // Redeclare events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    ERC1155Lootbox private lootbox;
    ERC1155Items private token;
    ERC1155Items private token2;
    LootboxReentryMock private reentryAttacker;

    address private proxyOwner;
    address private owner;

    IERC1155LootboxFunctions.BoxContent[] private boxContents;

    function setUp() public {
        owner = makeAddr("owner");
        proxyOwner = makeAddr("proxyOwner");

        vm.deal(address(this), 100 ether);
        vm.deal(owner, 100 ether);

        token = new ERC1155Items();
        token.initialize(address(this), "test", "ipfs://", "ipfs://", address(this), 0);

        token2 = new ERC1155Items();
        token2.initialize(address(this), "test2", "ipfs://", "ipfs://", address(this), 0);

        ERC1155LootboxFactory factory = new ERC1155LootboxFactory(address(this));
        lootbox = ERC1155Lootbox(factory.deploy(proxyOwner, owner, "name", "baseURI", "contractURI", address(this), 0));

        reentryAttacker = new LootboxReentryMock(address(lootbox));

        token.grantRole(keccak256("MINTER_ROLE"), address(lootbox));
        token2.grantRole(keccak256("MINTER_ROLE"), address(lootbox));

        _prepareBoxContents();
        (bytes32 root,) = TestHelper.getMerklePartsBoxes(boxContents, 0);

        vm.prank(owner);
        lootbox.setBoxContent(root, 3);
    }

    function testReinitializeFails() public {
        vm.expectRevert(InvalidInitialization.selector);
        lootbox.initialize(owner, "name", "baseURI", "contractURI", address(this), 0);
    }

    function testSupportsInterface() public view {
        assertTrue(lootbox.supportsInterface(type(IERC165).interfaceId));
        assertTrue(lootbox.supportsInterface(type(IERC1155).interfaceId));
        assertTrue(lootbox.supportsInterface(type(IERC1155ItemsFunctions).interfaceId));
        assertTrue(lootbox.supportsInterface(type(IERC1155LootboxFunctions).interfaceId));
    }

    /**
     * Test all public selectors for collisions against the proxy admin functions.
     * @dev yarn ts-node scripts/outputSelectors.ts
     */
    function testSelectorCollision() public pure {
        checkSelectorCollision(0xa217fddf); // DEFAULT_ADMIN_ROLE()
        checkSelectorCollision(0x00fdd58e); // balanceOf(address,uint256)
        checkSelectorCollision(0x4e1273f4); // balanceOfBatch(address[],uint256[])
        checkSelectorCollision(0x6c0360eb); // baseURI()
        checkSelectorCollision(0x20ec271b); // batchBurn(uint256[],uint256[])
        checkSelectorCollision(0xb48ab8b6); // batchMint(address,uint256[],uint256[],bytes)
        checkSelectorCollision(0x9cd59aea); // boxSupply()
        checkSelectorCollision(0xb390c0ab); // burn(uint256,uint256)
        checkSelectorCollision(0x3c7a3aff); // commit()
        checkSelectorCollision(0xe8a3d485); // contractURI()
        checkSelectorCollision(0x9237b855); // getRevealId(address)
        checkSelectorCollision(0x248a9ca3); // getRoleAdmin(bytes32)
        checkSelectorCollision(0x9010d07c); // getRoleMember(bytes32,uint256)
        checkSelectorCollision(0xca15c873); // getRoleMemberCount(bytes32)
        checkSelectorCollision(0x2f2ff15d); // grantRole(bytes32,address)
        checkSelectorCollision(0x91d14854); // hasRole(bytes32,address)
        checkSelectorCollision(0xf8954818); // initialize(address,string,string,string,address,uint96)
        checkSelectorCollision(0xe985e9c5); // isApprovedForAll(address,address)
        checkSelectorCollision(0x2eb4a7ab); // merkleRoot()
        checkSelectorCollision(0x731133e9); // mint(address,uint256,uint256,bytes)
        checkSelectorCollision(0x06fdde03); // name()
        checkSelectorCollision(0x5789e3ad); // refundBox()
        checkSelectorCollision(0x36568abe); // renounceRole(bytes32,address)
        checkSelectorCollision(0xe6f18485); // reveal(address,(address[],uint256[],uint256[]),bytes32[])
        checkSelectorCollision(0xd547741f); // revokeRole(bytes32,address)
        checkSelectorCollision(0x2a55205a); // royaltyInfo(uint256,uint256)
        checkSelectorCollision(0x2eb2c2d6); // safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)
        checkSelectorCollision(0xf242432a); // safeTransferFrom(address,address,uint256,uint256,bytes)
        checkSelectorCollision(0xa22cb465); // setApprovalForAll(address,bool)
        checkSelectorCollision(0x7e518ec8); // setBaseMetadataURI(string)
        checkSelectorCollision(0x5c798a2a); // setBoxContent(bytes32,uint256)
        checkSelectorCollision(0x0b5ee006); // setContractName(string)
        checkSelectorCollision(0x938e3d7b); // setContractURI(string)
        checkSelectorCollision(0x04634d8d); // setDefaultRoyalty(address,uint96)
        checkSelectorCollision(0x5944c753); // setTokenRoyalty(uint256,address,uint96)
        checkSelectorCollision(0x01ffc9a7); // supportsInterface(bytes4)
        checkSelectorCollision(0x2693ebf2); // tokenSupply(uint256)
        checkSelectorCollision(0x18160ddd); // totalSupply()
        checkSelectorCollision(0x0e89341c); // uri(uint256)
    }

    function testOwnerHasRoles() public view {
        assertTrue(lootbox.hasRole(lootbox.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(lootbox.hasRole(keccak256("METADATA_ADMIN_ROLE"), owner));
        assertTrue(lootbox.hasRole(keccak256("MINTER_ROLE"), owner));
        assertTrue(lootbox.hasRole(keccak256("ROYALTY_ADMIN_ROLE"), owner));
        assertTrue(lootbox.hasRole(keccak256("MINT_ADMIN_ROLE"), owner));
    }

    function testFactoryDetermineAddress(
        address _proxyOwner,
        address tokenOwner,
        string memory name,
        string memory baseURI,
        string memory contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) public {
        vm.assume(_proxyOwner != address(0));
        vm.assume(tokenOwner != address(0));
        vm.assume(royaltyReceiver != address(0));
        royaltyFeeNumerator = uint96(bound(royaltyFeeNumerator, 0, 10_000));
        ERC1155LootboxFactory factory = new ERC1155LootboxFactory(address(this));
        address deployedAddr =
            factory.deploy(_proxyOwner, tokenOwner, name, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator);
        address predictedAddr = factory.determineAddress(
            _proxyOwner, tokenOwner, name, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator
        );
        assertEq(deployedAddr, predictedAddr);
    }

    function testCommitWithBalance(address user) public {
        assumeSafeAddress(user);
        _commit(user);
        vm.assertEq(lootbox.balanceOf(user, 1), 0);
    }

    function testCommitNoBalance(address user) public {
        assumeSafeAddress(user);
        vm.prank(user);
        vm.expectRevert(NoBalance.selector);
        lootbox.commit();
    }

    function testCommitPendingReveal(address user) public {
        assumeSafeAddress(user);
        _commit(user);
        vm.prank(user);
        vm.expectRevert(PendingReveal.selector);
        lootbox.commit();
    }

    function testRefundNoCommit(address user) public {
        vm.expectRevert(NoCommit.selector);
        lootbox.refundBox(user);
    }

    function testRefundPendingReveal(address user) public {
        assumeSafeAddress(user);
        _commit(user);

        vm.roll(block.number + 255);
        vm.expectRevert(PendingReveal.selector);
        lootbox.refundBox(user);
    }

    function testRefundExpiredCommit(address user) public {
        assumeSafeAddress(user);
        _commit(user);

        vm.roll(block.number + 300);
        lootbox.refundBox(user);
        vm.assertEq(lootbox.balanceOf(user, 1), 1);
    }

    function testGetRevealIdNoCommit(address user) public {
        vm.expectRevert(NoCommit.selector);
        lootbox.getRevealId(user);
    }

    function testGetRevealIdInvalidCommit(address user) public {
        assumeSafeAddress(user);
        _commit(user);

        vm.roll(block.number + 300);
        vm.expectRevert(InvalidCommit.selector);
        lootbox.getRevealId(user);
    }

    function testGetRevealIdSuccess(address user) public {
        assumeSafeAddress(user);
        vm.assertLt(_getRevealId(user), lootbox.boxSupply());
    }

    function testRevealSuccess(address user) public {
        assumeSafeAddress(user);
        uint256 revealIdx = _getRevealId(user);

        (, bytes32[] memory proof) = TestHelper.getMerklePartsBoxes(boxContents, revealIdx);

        IERC1155LootboxFunctions.BoxContent memory boxContent = boxContents[revealIdx];

        lootbox.reveal(user, boxContent, proof);

        for (uint256 i = 0; i < boxContent.tokenAddresses.length; i++) {
            for (uint256 j = 0; j < boxContent.tokenIds[i].length; j++) {
                vm.assertEq(
                    IERC1155(boxContent.tokenAddresses[i]).balanceOf(user, boxContent.tokenIds[i][j]),
                    boxContent.amounts[i][j]
                );
            }
        }
    }

    function testFinalRevealSuccess(address user, uint256 size, uint256 unclaimedIdx) public {
        assumeSafeAddress(user);
        size = bound(size, 2, 1000); //FIXME 10000
        unclaimedIdx = bound(unclaimedIdx, 0, size - 1);

        ERC1155LootboxHack lootboxHack = new ERC1155LootboxHack();
        lootboxHack.initialize(owner, "name", "baseURI", "contractURI", address(this), 0);
        lootbox = lootboxHack;

        // Prepare massive box contents (empty)
        boxContents = new IERC1155LootboxFunctions.BoxContent[](size);
        (bytes32 root,) = TestHelper.getMerklePartsBoxes(boxContents, 0);
        vm.prank(owner);
        lootbox.setBoxContent(root, size);

        // Mark all claimed except one
        lootboxHack.setAllExceptOneClaimed(unclaimedIdx);

        // Mint box to user
        vm.prank(owner);
        lootbox.mint(user, 1, 1, "box");

        // Commit
        vm.prank(user);
        lootbox.commit();

        // Reveal
        vm.roll(block.number + 3);
        uint256 revealIdx = lootbox.getRevealId(user);
        (, bytes32[] memory proof) = TestHelper.getMerklePartsBoxes(boxContents, revealIdx);
        IERC1155LootboxFunctions.BoxContent memory boxContent = boxContents[unclaimedIdx];
        lootbox.reveal(user, boxContent, proof);

        vm.assertEq(token.balanceOf(user, 1), 0);
    }

    function testRevealInvalidBoxContent(address user) public {
        assumeSafeAddress(user);
        uint256 revealIdx = _getRevealId(user);

        vm.assume(revealIdx > 0);

        (, bytes32[] memory proof) = TestHelper.getMerklePartsBoxes(boxContents, revealIdx);

        IERC1155LootboxFunctions.BoxContent memory boxContent = boxContents[revealIdx - 1];

        vm.expectRevert(InvalidProof.selector);
        lootbox.reveal(user, boxContent, proof);
    }

    function testRevealInvalidRevealIdx(address user) public {
        assumeSafeAddress(user);
        uint256 revealIdx = _getRevealId(user);

        vm.assume(revealIdx > 0);

        (, bytes32[] memory proof) = TestHelper.getMerklePartsBoxes(boxContents, revealIdx - 1);

        IERC1155LootboxFunctions.BoxContent memory boxContent = boxContents[revealIdx];

        vm.expectRevert(InvalidProof.selector);
        lootbox.reveal(user, boxContent, proof);
    }

    function testRevealAfterAllOpened(address user) public {
        assumeSafeAddress(user);

        uint256 boxSupply = lootbox.boxSupply();

        bool[] memory revealed = new bool[](boxSupply);
        for (uint256 i = 0; i < boxSupply; i++) {
            uint256 revealIdx = _getRevealId(user);
            vm.assertEq(revealed[revealIdx], false);

            (, bytes32[] memory proof) = TestHelper.getMerklePartsBoxes(boxContents, revealIdx);

            IERC1155LootboxFunctions.BoxContent memory boxContent = boxContents[revealIdx];

            lootbox.reveal(user, boxContent, proof);
            revealed[revealIdx] = true;
        }
        _commit(user);
        vm.roll(block.number + 3);

        vm.expectRevert(AllBoxesOpened.selector);
        lootbox.getRevealId(user);
    }

    function testRevealReentryAttack() public {
        vm.prank(owner);
        lootbox.mint(address(reentryAttacker), 1, 1, "box");

        reentryAttacker.commit();

        vm.roll(block.number + 3);
        uint256 revealIdx = lootbox.getRevealId(address(reentryAttacker));

        (, bytes32[] memory proof) = TestHelper.getMerklePartsBoxes(boxContents, revealIdx);

        IERC1155LootboxFunctions.BoxContent memory boxContent = boxContents[revealIdx];

        reentryAttacker.setBoxAndProof(proof, boxContent);

        vm.expectRevert(NoCommit.selector);
        lootbox.reveal(address(reentryAttacker), boxContent, proof);
    }

    function testCantRefundAfterReveal(address user) public {
        assumeSafeAddress(user);
        uint256 revealIdx = _getRevealId(user);

        (, bytes32[] memory proof) = TestHelper.getMerklePartsBoxes(boxContents, revealIdx);

        IERC1155LootboxFunctions.BoxContent memory boxContent = boxContents[revealIdx];

        lootbox.reveal(user, boxContent, proof);

        vm.expectRevert(NoCommit.selector);
        lootbox.refundBox(user);
    }

    // Common functions

    function _prepareBoxContents() internal {
        boxContents = new IERC1155LootboxFunctions.BoxContent[](3);

        // Multiple tokens on single address
        boxContents[0].tokenAddresses = new address[](1);
        boxContents[0].tokenAddresses[0] = address(token);
        boxContents[0].tokenIds = new uint256[][](1);
        boxContents[0].tokenIds[0] = new uint256[](2);
        boxContents[0].tokenIds[0][0] = 1;
        boxContents[0].tokenIds[0][1] = 2;
        boxContents[0].amounts = new uint256[][](1);
        boxContents[0].amounts[0] = new uint256[](2);
        boxContents[0].amounts[0][0] = 10;
        boxContents[0].amounts[0][1] = 5;

        // Single token on single address
        boxContents[1].tokenAddresses = new address[](1);
        boxContents[1].tokenAddresses[0] = address(token);
        boxContents[1].tokenIds = new uint256[][](1);
        boxContents[1].tokenIds[0] = new uint256[](1);
        boxContents[1].tokenIds[0][0] = 3;
        boxContents[1].amounts = new uint256[][](1);
        boxContents[1].amounts[0] = new uint256[](1);
        boxContents[1].amounts[0][0] = 15;

        // Single token on multiple addresses
        boxContents[2].tokenAddresses = new address[](2);
        boxContents[2].tokenAddresses[0] = address(token);
        boxContents[2].tokenAddresses[1] = address(token2);
        boxContents[2].tokenIds = new uint256[][](2);
        boxContents[2].tokenIds[0] = new uint256[](1);
        boxContents[2].tokenIds[0][0] = 4;
        boxContents[2].tokenIds[1] = new uint256[](1);
        boxContents[2].tokenIds[1][0] = 5;
        boxContents[2].amounts = new uint256[][](2);
        boxContents[2].amounts[0] = new uint256[](1);
        boxContents[2].amounts[0][0] = 20;
        boxContents[2].amounts[1] = new uint256[](1);
        boxContents[2].amounts[1][0] = 10;
    }

    function _commit(address user) internal {
        vm.prank(owner);
        lootbox.mint(user, 1, 1, "box");

        vm.prank(user);
        lootbox.commit();
    }

    function _getRevealId(address user) internal returns (uint256 revealIdx) {
        _commit(user);
        vm.roll(block.number + 3);
        revealIdx = lootbox.getRevealId(user);
    }
}
