// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {TestHelper} from "../../../TestHelper.sol";
import {PackReentryMock} from "../../../_mocks/PackReentryMock.sol";
import {ERC1155Items} from "src/tokens/ERC1155/presets/items/ERC1155Items.sol";
import {ERC1155Pack} from "src/tokens/ERC1155/presets/pack/ERC1155Pack.sol";
import {IERC1155Pack} from "src/tokens/ERC1155/presets/pack/IERC1155Pack.sol";
import {IERC1155ItemsSignals, IERC1155ItemsFunctions} from "src/tokens/ERC1155/presets/items/IERC1155Items.sol";
import {ERC1155PackFactory} from "src/tokens/ERC1155/presets/pack/ERC1155PackFactory.sol";

// Interfaces
import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract ERC1155PackHack is ERC1155Pack {
    function setAllExceptOneClaimed(uint256 _idx) public {
        remainingSupply = 1;
        // Update _availableIndices to point to the last index
        _availableIndices[0] = _idx;
    }
}

contract ERC1155PackTest is TestHelper, IERC1155ItemsSignals {
    // Redeclare events
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    ERC1155Pack private pack;
    ERC1155Items private token;
    ERC1155Items private token2;
    PackReentryMock private reentryAttacker;

    address private proxyOwner;
    address private owner;

    IERC1155Pack.PackContent[] private packsContent;

    function setUp() public {
        owner = makeAddr("owner");
        proxyOwner = makeAddr("proxyOwner");

        vm.deal(address(this), 100 ether);
        vm.deal(owner, 100 ether);

        token = new ERC1155Items();
        token.initialize(
            address(this),
            "test",
            "ipfs://",
            "ipfs://",
            address(this),
            0
        );

        token2 = new ERC1155Items();
        token2.initialize(
            address(this),
            "test2",
            "ipfs://",
            "ipfs://",
            address(this),
            0
        );

        ERC1155PackFactory factory = new ERC1155PackFactory(address(this));

        _preparePacksContent();
        (bytes32 root, ) = TestHelper.getMerklePartsPacks(packsContent, 0);

        pack = ERC1155Pack(
            factory.deploy(
                proxyOwner,
                owner,
                "name",
                "baseURI",
                "contractURI",
                address(this),
                0,
                root,
                3
            )
        );

        reentryAttacker = new PackReentryMock(address(pack));

        token.grantRole(keccak256("MINTER_ROLE"), address(pack));
        token2.grantRole(keccak256("MINTER_ROLE"), address(pack));
    }

    function testReinitializeFails() public {
        _preparePacksContent();
        (bytes32 root, ) = TestHelper.getMerklePartsPacks(packsContent, 0);

        vm.expectRevert(InvalidInitialization.selector);
        pack.initialize(
            owner,
            "name",
            "baseURI",
            "contractURI",
            address(this),
            0,
            root,
            3
        );
    }

    function testSupportsInterface() public view {
        assertTrue(pack.supportsInterface(type(IERC165).interfaceId));
        assertTrue(pack.supportsInterface(type(IERC1155).interfaceId));
        assertTrue(
            pack.supportsInterface(type(IERC1155ItemsFunctions).interfaceId)
        );
        assertTrue(pack.supportsInterface(type(IERC1155Pack).interfaceId));
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
        checkSelectorCollision(0xb390c0ab); // burn(uint256,uint256)
        checkSelectorCollision(0x3c7a3aff); // commit()
        checkSelectorCollision(0xe8a3d485); // contractURI()
        checkSelectorCollision(0xbd93f5a0); // getRevealIdx(address)
        checkSelectorCollision(0x248a9ca3); // getRoleAdmin(bytes32)
        checkSelectorCollision(0x9010d07c); // getRoleMember(bytes32,uint256)
        checkSelectorCollision(0xca15c873); // getRoleMemberCount(bytes32)
        checkSelectorCollision(0x2f2ff15d); // grantRole(bytes32,address)
        checkSelectorCollision(0x91d14854); // hasRole(bytes32,address)
        checkSelectorCollision(0xf8954818); // initialize(address,string,string,string,address,uint96)
        checkSelectorCollision(0x1d14ef67); // initialize(address,string,string,string,address,uint96,bytes32,uint256)
        checkSelectorCollision(0xe985e9c5); // isApprovedForAll(address,address)
        checkSelectorCollision(0x2eb4a7ab); // merkleRoot()
        checkSelectorCollision(0x731133e9); // mint(address,uint256,uint256,bytes)
        checkSelectorCollision(0x06fdde03); // name()
        checkSelectorCollision(0x6f225bd4); // refundPack(address)
        checkSelectorCollision(0xda0239a6); // remainingSupply()
        checkSelectorCollision(0x36568abe); // renounceRole(bytes32,address)
        checkSelectorCollision(0xa206e5e1); // reveal(address,(address[],uint256[][],uint256[][]),bytes32[])
        checkSelectorCollision(0xd547741f); // revokeRole(bytes32,address)
        checkSelectorCollision(0x2a55205a); // royaltyInfo(uint256,uint256)
        checkSelectorCollision(0x2eb2c2d6); // safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)
        checkSelectorCollision(0xf242432a); // safeTransferFrom(address,address,uint256,uint256,bytes)
        checkSelectorCollision(0xa22cb465); // setApprovalForAll(address,bool)
        checkSelectorCollision(0x7e518ec8); // setBaseMetadataURI(string)
        checkSelectorCollision(0x0b5ee006); // setContractName(string)
        checkSelectorCollision(0x938e3d7b); // setContractURI(string)
        checkSelectorCollision(0x04634d8d); // setDefaultRoyalty(address,uint96)
        checkSelectorCollision(0x275bf183); // setPacksContent(bytes32,uint256)
        checkSelectorCollision(0x5944c753); // setTokenRoyalty(uint256,address,uint96)
        checkSelectorCollision(0x047fc9aa); // supply()
        checkSelectorCollision(0x01ffc9a7); // supportsInterface(bytes4)
        checkSelectorCollision(0x2693ebf2); // tokenSupply(uint256)
        checkSelectorCollision(0x18160ddd); // totalSupply()
        checkSelectorCollision(0x0e89341c); // uri(uint256)
    }

    function testOwnerHasRoles() public view {
        assertTrue(pack.hasRole(pack.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(pack.hasRole(keccak256("METADATA_ADMIN_ROLE"), owner));
        assertTrue(pack.hasRole(keccak256("MINTER_ROLE"), owner));
        assertTrue(pack.hasRole(keccak256("ROYALTY_ADMIN_ROLE"), owner));
        assertTrue(pack.hasRole(keccak256("PACK_ADMIN_ROLE"), owner));
    }

    function testFactoryDetermineAddress(
        address _proxyOwner,
        address tokenOwner,
        string memory name,
        string memory baseURI,
        string memory contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        bytes32 merkleRoot,
        uint256 supply
    ) public {
        vm.assume(_proxyOwner != address(0));
        vm.assume(tokenOwner != address(0));
        vm.assume(royaltyReceiver != address(0));
        royaltyFeeNumerator = uint96(bound(royaltyFeeNumerator, 0, 10_000));
        ERC1155PackFactory factory = new ERC1155PackFactory(
            address(this)
        );
        address deployedAddr = factory.deploy(
            _proxyOwner,
            tokenOwner,
            name,
            baseURI,
            contractURI,
            royaltyReceiver,
            royaltyFeeNumerator,
            merkleRoot,
            supply
        );
        address predictedAddr = factory.determineAddress(
            _proxyOwner,
            tokenOwner,
            name,
            baseURI,
            contractURI,
            royaltyReceiver,
            royaltyFeeNumerator
        );
        assertEq(deployedAddr, predictedAddr);
    }

    function testCommitWithBalance(address user) public {
        assumeSafeAddress(user);
        _commit(user);
        vm.assertEq(pack.balanceOf(user, 1), 0);
    }

    function testCommitNoBalance(address user) public {
        assumeSafeAddress(user);
        vm.prank(user);
        vm.expectRevert(IERC1155Pack.NoBalance.selector);
        pack.commit();
    }

    function testCommitPendingReveal(address user) public {
        assumeSafeAddress(user);
        _commit(user);
        vm.prank(user);
        vm.expectRevert(IERC1155Pack.PendingReveal.selector);
        pack.commit();
    }

    function testRefundNoCommit(address user) public {
        vm.expectRevert(IERC1155Pack.NoCommit.selector);
        pack.refundPack(user);
    }

    function testRefundPendingReveal(address user) public {
        assumeSafeAddress(user);
        _commit(user);

        vm.roll(block.number + 255);
        vm.expectRevert(IERC1155Pack.PendingReveal.selector);
        pack.refundPack(user);
    }

    function testRefundExpiredCommit(address user) public {
        assumeSafeAddress(user);
        _commit(user);

        vm.roll(block.number + 300);
        pack.refundPack(user);
        vm.assertEq(pack.balanceOf(user, 1), 1);
    }

    function testGetRevealIdxNoCommit(address user) public {
        vm.expectRevert(IERC1155Pack.NoCommit.selector);
        pack.getRevealIdx(user);
    }

    function testGetRevealIdxInvalidCommit(address user) public {
        assumeSafeAddress(user);
        _commit(user);

        vm.roll(block.number + 300);
        vm.expectRevert(IERC1155Pack.InvalidCommit.selector);
        pack.getRevealIdx(user);
    }

    function testGetRevealIdxSuccess(address user) public {
        assumeSafeAddress(user);
        vm.assertLt(_getRevealIdx(user), pack.supply());
    }

    function testRevealSuccess(address user) public {
        assumeSafeAddress(user);
        uint256 revealIdx = _getRevealIdx(user);

        (, bytes32[] memory proof) = TestHelper.getMerklePartsPacks(
            packsContent,
            revealIdx
        );

        IERC1155Pack.PackContent memory packContent = packsContent[revealIdx];

        pack.reveal(user, packContent, proof);

        for (uint256 i = 0; i < packContent.tokenAddresses.length; i++) {
            for (uint256 j = 0; j < packContent.tokenIds[i].length; j++) {
                vm.assertEq(
                    IERC1155(packContent.tokenAddresses[i]).balanceOf(
                        user,
                        packContent.tokenIds[i][j]
                    ),
                    packContent.amounts[i][j]
                );
            }
        }
    }

    function testFinalRevealSuccess(
        address user,
        uint256 size,
        uint256 unclaimedIdx
    ) public {
        assumeSafeAddress(user);
        size = bound(size, 2, 1000); //FIXME 10000
        unclaimedIdx = bound(unclaimedIdx, 0, size - 1);

        // Prepare massive pack contents (empty)
        packsContent = new IERC1155Pack.PackContent[](size);
        (bytes32 root, ) = TestHelper.getMerklePartsPacks(packsContent, 0);

        ERC1155PackHack packHack = new ERC1155PackHack();
        packHack.initialize(
            owner,
            "name",
            "baseURI",
            "contractURI",
            address(this),
            0,
            root,
            size
        );
        
        pack = packHack;

        // Mark all claimed except one
        packHack.setAllExceptOneClaimed(unclaimedIdx);

        // Mint pack to user
        vm.prank(owner);
        pack.mint(user, 1, 1, "pack");

        // Commit
        vm.prank(user);
        pack.commit();

        // Reveal
        vm.roll(block.number + 3);
        uint256 revealIdx = pack.getRevealIdx(user);
        (, bytes32[] memory proof) = TestHelper.getMerklePartsPacks(
            packsContent,
            revealIdx
        );
        IERC1155Pack.PackContent memory packContent = packsContent[
            unclaimedIdx
        ];
        pack.reveal(user, packContent, proof);

        vm.assertEq(token.balanceOf(user, 1), 0);
    }

    function testRevealInvalidPackContent(address user) public {
        assumeSafeAddress(user);
        uint256 revealIdx = _getRevealIdx(user);

        vm.assume(revealIdx > 0);

        (, bytes32[] memory proof) = TestHelper.getMerklePartsPacks(
            packsContent,
            revealIdx
        );

        IERC1155Pack.PackContent memory packContent = packsContent[
            revealIdx - 1
        ];

        vm.expectRevert(IERC1155Pack.InvalidProof.selector);
        pack.reveal(user, packContent, proof);
    }

    function testRevealInvalidRevealIdx(address user) public {
        assumeSafeAddress(user);
        uint256 revealIdx = _getRevealIdx(user);

        vm.assume(revealIdx > 0);

        (, bytes32[] memory proof) = TestHelper.getMerklePartsPacks(
            packsContent,
            revealIdx - 1
        );

        IERC1155Pack.PackContent memory packContent = packsContent[revealIdx];

        vm.expectRevert(IERC1155Pack.InvalidProof.selector);
        pack.reveal(user, packContent, proof);
    }

    function testRevealAfterAllOpened(address user) public {
        assumeSafeAddress(user);

        uint256 packSupply = pack.supply();

        bool[] memory revealed = new bool[](packSupply);
        for (uint256 i = 0; i < packSupply; i++) {
            uint256 revealIdx = _getRevealIdx(user);
            vm.assertEq(revealed[revealIdx], false);

            (, bytes32[] memory proof) = TestHelper.getMerklePartsPacks(
                packsContent,
                revealIdx
            );

            IERC1155Pack.PackContent memory packContent = packsContent[
                revealIdx
            ];

            pack.reveal(user, packContent, proof);
            revealed[revealIdx] = true;
        }
        _commit(user);
        vm.roll(block.number + 3);

        vm.expectRevert(IERC1155Pack.AllPacksOpened.selector);
        pack.getRevealIdx(user);
    }

    function testRevealReentryAttack() public {
        vm.prank(owner);
        pack.mint(address(reentryAttacker), 1, 1, "pack");

        reentryAttacker.commit();

        vm.roll(block.number + 3);
        uint256 revealIdx = pack.getRevealIdx(address(reentryAttacker));

        (, bytes32[] memory proof) = TestHelper.getMerklePartsPacks(
            packsContent,
            revealIdx
        );

        IERC1155Pack.PackContent memory packContent = packsContent[revealIdx];

        reentryAttacker.setPackAndProof(proof, packContent);

        vm.expectRevert(IERC1155Pack.NoCommit.selector);
        pack.reveal(address(reentryAttacker), packContent, proof);
    }

    function testCantRefundAfterReveal(address user) public {
        assumeSafeAddress(user);
        uint256 revealIdx = _getRevealIdx(user);

        (, bytes32[] memory proof) = TestHelper.getMerklePartsPacks(
            packsContent,
            revealIdx
        );

        IERC1155Pack.PackContent memory packContent = packsContent[revealIdx];

        pack.reveal(user, packContent, proof);

        vm.expectRevert(IERC1155Pack.NoCommit.selector);
        pack.refundPack(user);
    }

    // Common functions

    function _preparePacksContent() internal {
        packsContent = new IERC1155Pack.PackContent[](3);

        // Multiple tokens on single address
        packsContent[0].tokenAddresses = new address[](1);
        packsContent[0].tokenAddresses[0] = address(token);
        packsContent[0].tokenIds = new uint256[][](1);
        packsContent[0].tokenIds[0] = new uint256[](2);
        packsContent[0].tokenIds[0][0] = 1;
        packsContent[0].tokenIds[0][1] = 2;
        packsContent[0].amounts = new uint256[][](1);
        packsContent[0].amounts[0] = new uint256[](2);
        packsContent[0].amounts[0][0] = 10;
        packsContent[0].amounts[0][1] = 5;

        // Single token on single address
        packsContent[1].tokenAddresses = new address[](1);
        packsContent[1].tokenAddresses[0] = address(token);
        packsContent[1].tokenIds = new uint256[][](1);
        packsContent[1].tokenIds[0] = new uint256[](1);
        packsContent[1].tokenIds[0][0] = 3;
        packsContent[1].amounts = new uint256[][](1);
        packsContent[1].amounts[0] = new uint256[](1);
        packsContent[1].amounts[0][0] = 15;

        // Single token on multiple addresses
        packsContent[2].tokenAddresses = new address[](2);
        packsContent[2].tokenAddresses[0] = address(token);
        packsContent[2].tokenAddresses[1] = address(token2);
        packsContent[2].tokenIds = new uint256[][](2);
        packsContent[2].tokenIds[0] = new uint256[](1);
        packsContent[2].tokenIds[0][0] = 4;
        packsContent[2].tokenIds[1] = new uint256[](1);
        packsContent[2].tokenIds[1][0] = 5;
        packsContent[2].amounts = new uint256[][](2);
        packsContent[2].amounts[0] = new uint256[](1);
        packsContent[2].amounts[0][0] = 20;
        packsContent[2].amounts[1] = new uint256[](1);
        packsContent[2].amounts[1][0] = 10;
    }

    function _commit(address user) internal {
        vm.prank(owner);
        pack.mint(user, 1, 1, "pack");

        vm.prank(user);
        pack.commit();
    }

    function _getRevealIdx(address user) internal returns (uint256 revealIdx) {
        _commit(user);
        vm.roll(block.number + 3);
        revealIdx = pack.getRevealIdx(user);
    }
}
