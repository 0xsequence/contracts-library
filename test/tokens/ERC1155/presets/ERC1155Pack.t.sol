// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import { TestHelper } from "../../../TestHelper.sol";
import { ERC1155Recipient } from "../../../_mocks/ERC1155Recipient.sol";
import { PackReentryMock } from "../../../_mocks/PackReentryMock.sol";

import { ERC1155Items } from "src/tokens/ERC1155/presets/items/ERC1155Items.sol";
import { IERC1155ItemsFunctions, IERC1155ItemsSignals } from "src/tokens/ERC1155/presets/items/IERC1155Items.sol";

import { ERC1155Pack } from "src/tokens/ERC1155/presets/pack/ERC1155Pack.sol";
import { ERC1155PackFactory } from "src/tokens/ERC1155/presets/pack/ERC1155PackFactory.sol";
import { IERC1155Pack } from "src/tokens/ERC1155/presets/pack/IERC1155Pack.sol";
import { ERC1155Holder } from "src/tokens/ERC1155/utility/holder/ERC1155Holder.sol";
import { ERC721Items } from "src/tokens/ERC721/presets/items/ERC721Items.sol";

import { IERC1155 } from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import { IERC721 } from "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import { IERC165 } from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

import { ISignalsImplicitMode } from "signals-implicit-mode/src/helper/SignalsImplicitMode.sol";

import { ERC1155 } from "solady/tokens/ERC1155.sol";

contract ERC1155PackHack is ERC1155Pack {

    constructor(
        address _erc1155Holder
    ) ERC1155Pack(_erc1155Holder) { }

    function setAllExceptOneClaimed(
        uint256 _idx
    ) public {
        remainingSupply[0] = 1;
        // Update _availableIndices to point to the last index
        _availableIndices[0][0] = _idx;
    }

}

contract ERC1155PackTest is TestHelper, IERC1155ItemsSignals {

    // Redeclare events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    ERC1155Pack private pack;
    ERC1155Items private token;
    ERC1155Items private token2;
    ERC721Items private token721;
    PackReentryMock private reentryAttacker;
    ERC1155Holder private holder;

    address private proxyOwner;
    address private owner;

    IERC1155Pack.PackContent[] private packsContent;

    function setUp() public {
        owner = makeAddr("owner");
        proxyOwner = makeAddr("proxyOwner");

        vm.deal(address(this), 100 ether);
        vm.deal(owner, 100 ether);

        token = new ERC1155Items();
        token.initialize(address(this), "test", "ipfs://", "ipfs://", address(this), 0, address(0), bytes32(0));

        token2 = new ERC1155Items();
        token2.initialize(address(this), "test2", "ipfs://", "ipfs://", address(this), 0, address(0), bytes32(0));

        token721 = new ERC721Items();
        token721.initialize(
            address(this), "test721", "test721", "ipfs://", "ipfs://", address(this), 0, address(0), bytes32(0)
        );

        holder = new ERC1155Holder();
        ERC1155PackFactory factory = new ERC1155PackFactory(address(this), address(holder));

        _preparePacksContent();
        (bytes32 root,) = TestHelper.getMerklePartsPacks(packsContent, 0);

        pack = ERC1155Pack(
            factory.deploy(
                proxyOwner, owner, "name", "baseURI", "contractURI", address(this), 0, address(0), bytes32(0)
            )
        );

        vm.prank(owner);
        pack.setPacksContent(root, 4, 0);

        reentryAttacker = new PackReentryMock(address(pack));

        token.grantRole(keccak256("MINTER_ROLE"), address(pack));
        token2.grantRole(keccak256("MINTER_ROLE"), address(pack));
        token721.grantRole(keccak256("MINTER_ROLE"), address(pack));
    }

    function testReinitializeFails() public {
        vm.expectRevert(InvalidInitialization.selector);
        pack.initialize(owner, "name", "baseURI", "contractURI", address(this), 0, address(0), bytes32(0));
    }

    function testSupportsInterface() public view {
        assertTrue(pack.supportsInterface(type(IERC165).interfaceId));
        assertTrue(pack.supportsInterface(type(IERC1155).interfaceId));
        assertTrue(pack.supportsInterface(type(IERC1155ItemsFunctions).interfaceId));
        assertTrue(pack.supportsInterface(type(IERC1155Pack).interfaceId));
        assertTrue(pack.supportsInterface(type(ISignalsImplicitMode).interfaceId));
    }

    /**
     * Test all public selectors for collisions against the proxy admin functions.
     * @dev pnpm ts-node scripts/outputSelectors.ts
     */
    function testSelectorCollision() public pure {
        checkSelectorCollision(0xa217fddf); // DEFAULT_ADMIN_ROLE()
        checkSelectorCollision(0x9d043a66); // acceptImplicitRequest(address,(address,bytes4,bytes32,bytes32,bytes,(string,uint64)),(address,uint256,bytes,uint256,bool,bool,uint256))
        checkSelectorCollision(0x00fdd58e); // balanceOf(address,uint256)
        checkSelectorCollision(0x4e1273f4); // balanceOfBatch(address[],uint256[])
        checkSelectorCollision(0x6c0360eb); // baseURI()
        checkSelectorCollision(0x20ec271b); // batchBurn(uint256[],uint256[])
        checkSelectorCollision(0xb48ab8b6); // batchMint(address,uint256[],uint256[],bytes)
        checkSelectorCollision(0xb390c0ab); // burn(uint256,uint256)
        checkSelectorCollision(0xf4f98ad5); // commit(uint256)
        checkSelectorCollision(0xe8a3d485); // contractURI()
        checkSelectorCollision(0x5377ab8f); // getRevealIdx(address,uint256)
        checkSelectorCollision(0x248a9ca3); // getRoleAdmin(bytes32)
        checkSelectorCollision(0x9010d07c); // getRoleMember(bytes32,uint256)
        checkSelectorCollision(0xca15c873); // getRoleMemberCount(bytes32)
        checkSelectorCollision(0x2f2ff15d); // grantRole(bytes32,address)
        checkSelectorCollision(0x91d14854); // hasRole(bytes32,address)
        checkSelectorCollision(0x8ff83ac1); // initialize(address,string,string,string,address,uint96,address,bytes32)
        checkSelectorCollision(0xccf69f42); // initialize(address,string,string,string,address,uint96,address,bytes32,bytes32,uint256)
        checkSelectorCollision(0xe985e9c5); // isApprovedForAll(address,address)
        checkSelectorCollision(0x3c70b357); // merkleRoot(uint256)
        checkSelectorCollision(0x731133e9); // mint(address,uint256,uint256,bytes)
        checkSelectorCollision(0x06fdde03); // name()
        checkSelectorCollision(0x167a59f7); // refundPack(address,uint256)
        checkSelectorCollision(0x47fda41a); // remainingSupply(uint256)
        checkSelectorCollision(0x36568abe); // renounceRole(bytes32,address)
        checkSelectorCollision(0xd67b333b); // reveal(address,(address[],bool[],uint256[][],uint256[][]),bytes32[],uint256)
        checkSelectorCollision(0xd547741f); // revokeRole(bytes32,address)
        checkSelectorCollision(0x2a55205a); // royaltyInfo(uint256,uint256)
        checkSelectorCollision(0x2eb2c2d6); // safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)
        checkSelectorCollision(0xf242432a); // safeTransferFrom(address,address,uint256,uint256,bytes)
        checkSelectorCollision(0xa22cb465); // setApprovalForAll(address,bool)
        checkSelectorCollision(0x7e518ec8); // setBaseMetadataURI(string)
        checkSelectorCollision(0x0b5ee006); // setContractName(string)
        checkSelectorCollision(0x938e3d7b); // setContractURI(string)
        checkSelectorCollision(0x04634d8d); // setDefaultRoyalty(address,uint96)
        checkSelectorCollision(0xed4c2ac7); // setImplicitModeProjectId(bytes32)
        checkSelectorCollision(0x0bb310de); // setImplicitModeValidator(address)
        checkSelectorCollision(0x50336a03); // setPacksContent(bytes32,uint256,uint256)
        checkSelectorCollision(0x5944c753); // setTokenRoyalty(uint256,address,uint96)
        checkSelectorCollision(0x35403023); // supply(uint256)
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
        assertTrue(pack.hasRole(keccak256("IMPLICIT_MODE_ADMIN_ROLE"), owner));
    }

    struct TestFactoryDetermineAddressParams {
        address proxyOwner;
        address tokenOwner;
        string name;
        string baseURI;
        string contractURI;
        address royaltyReceiver;
        uint96 royaltyFeeNumerator;
        address implicitModeValidator;
        bytes32 implicitModeProjectId;
        bytes32 merkleRoot;
        uint256 supply;
    }

    function testFactoryDetermineAddress(
        address holderFallback,
        address factoryOwner,
        TestFactoryDetermineAddressParams memory params
    ) public {
        vm.assume(params.proxyOwner != address(0));
        vm.assume(params.tokenOwner != address(0));
        vm.assume(params.royaltyReceiver != address(0));
        params.royaltyFeeNumerator = uint96(bound(params.royaltyFeeNumerator, 0, 10_000));
        ERC1155PackFactory factory = new ERC1155PackFactory(factoryOwner, holderFallback);
        address deployedAddr = factory.deploy(
            params.proxyOwner,
            params.tokenOwner,
            params.name,
            params.baseURI,
            params.contractURI,
            params.royaltyReceiver,
            params.royaltyFeeNumerator,
            params.implicitModeValidator,
            params.implicitModeProjectId
        );
        address predictedAddr = factory.determineAddress(
            params.proxyOwner,
            params.tokenOwner,
            params.name,
            params.baseURI,
            params.contractURI,
            params.royaltyReceiver,
            params.royaltyFeeNumerator,
            params.implicitModeValidator,
            params.implicitModeProjectId
        );
        assertEq(deployedAddr, predictedAddr);
    }

    function testCommitWithBalance(
        address user
    ) public {
        assumeSafeAddress(user);
        _commit(user);
        vm.assertEq(pack.balanceOf(user, 1), 0);
    }

    function testCommitNoBalance(
        address user
    ) public {
        assumeSafeAddress(user);
        vm.prank(user);
        vm.expectRevert(ERC1155.InsufficientBalance.selector);
        pack.commit(0);
    }

    function testCommitPendingReveal(
        address user
    ) public {
        assumeSafeAddress(user);
        _commit(user);
        vm.prank(user);
        vm.expectRevert(IERC1155Pack.PendingReveal.selector);
        pack.commit(0);
    }

    function testRefundNoCommit(
        address user
    ) public {
        vm.expectRevert(IERC1155Pack.NoCommit.selector);
        pack.refundPack(user, 0);
    }

    function testRefundPendingReveal(
        address user
    ) public {
        assumeSafeAddress(user);
        _commit(user);

        vm.roll(block.number + 255);
        vm.expectRevert(IERC1155Pack.PendingReveal.selector);
        pack.refundPack(user, 0);
    }

    function testRefundExpiredCommit(
        address user
    ) public {
        assumeSafeAddress(user);
        _commit(user);

        vm.roll(block.number + 300);
        pack.refundPack(user, 0);
        vm.assertEq(pack.balanceOf(user, 0), 1);
    }

    function testGetRevealIdxNoCommit(
        address user
    ) public {
        vm.expectRevert(IERC1155Pack.NoCommit.selector);
        pack.getRevealIdx(user, 0);
    }

    function testGetRevealIdxInvalidCommit(
        address user
    ) public {
        assumeSafeAddress(user);
        _commit(user);

        vm.roll(block.number + 300);
        vm.expectRevert(IERC1155Pack.InvalidCommit.selector);
        pack.getRevealIdx(user, 0);
    }

    function testGetRevealIdxSuccess(
        address user
    ) public {
        assumeSafeAddress(user);
        vm.assertLt(_getRevealIdx(user), pack.supply(0));
    }

    function testRevealSuccessToUser(
        address user
    ) public {
        assumeSafeAddress(user);
        uint256 revealIdx = _getRevealIdx(user);

        (, bytes32[] memory proof) = TestHelper.getMerklePartsPacks(packsContent, revealIdx);

        IERC1155Pack.PackContent memory packContent = packsContent[revealIdx];

        vm.prank(user);
        pack.reveal(user, packContent, proof, 0);

        for (uint256 i = 0; i < packContent.tokenAddresses.length; i++) {
            for (uint256 j = 0; j < packContent.tokenIds[i].length; j++) {
                if (packContent.isERC721[i]) {
                    vm.assertEq(IERC721(packContent.tokenAddresses[i]).ownerOf(packContent.tokenIds[i][j]), user);
                } else {
                    vm.assertEq(
                        IERC1155(packContent.tokenAddresses[i]).balanceOf(user, packContent.tokenIds[i][j]),
                        packContent.amounts[i][j]
                    );
                }
            }
        }
    }

    function testRevealSuccessToHolder(address user, address sender) public {
        assumeSafeAddress(user);
        vm.assume(sender != user);
        uint256 revealIdx = _getRevealIdx(user);

        (, bytes32[] memory proof) = TestHelper.getMerklePartsPacks(packsContent, revealIdx);

        IERC1155Pack.PackContent memory packContent = packsContent[revealIdx];

        vm.prank(sender);
        pack.reveal(user, packContent, proof, 0);

        for (uint256 i = 0; i < packContent.tokenAddresses.length; i++) {
            for (uint256 j = 0; j < packContent.tokenIds[i].length; j++) {
                if (packContent.isERC721[i]) {
                    // To user
                    vm.assertEq(IERC721(packContent.tokenAddresses[i]).ownerOf(packContent.tokenIds[i][j]), user);
                } else {
                    // To holder with claim
                    vm.assertEq(
                        IERC1155(packContent.tokenAddresses[i]).balanceOf(address(holder), packContent.tokenIds[i][j]),
                        packContent.amounts[i][j]
                    );
                    vm.assertEq(
                        holder.claims(user, packContent.tokenAddresses[i], packContent.tokenIds[i][j]),
                        packContent.amounts[i][j]
                    );
                }
            }
        }

        // After reveal, sender can claim tokens on behalf of user.
        // In pactice, this will be batched with revertOnError: false
        for (uint256 i = 0; i < packContent.tokenAddresses.length; i++) {
            if (!packContent.isERC721[i]) {
                vm.prank(sender);
                holder.claimBatch(user, packContent.tokenAddresses[i], packContent.tokenIds[i]);
            }
        }

        for (uint256 i = 0; i < packContent.tokenAddresses.length; i++) {
            if (!packContent.isERC721[i]) {
                for (uint256 j = 0; j < packContent.tokenIds[i].length; j++) {
                    // User now holds tokens
                    vm.assertEq(
                        IERC1155(packContent.tokenAddresses[i]).balanceOf(user, packContent.tokenIds[i][j]),
                        packContent.amounts[i][j]
                    );
                    vm.assertEq(holder.claims(user, packContent.tokenAddresses[i], packContent.tokenIds[i][j]), 0);
                }
            }
        }
    }

    function testFinalRevealSuccess(address user, uint256 size, uint256 unclaimedIdx) public {
        assumeSafeAddress(user);
        size = bound(size, 2, 1000); //FIXME 10000
        unclaimedIdx = bound(unclaimedIdx, 0, size - 1);

        // Prepare massive pack contents (empty)
        packsContent = new IERC1155Pack.PackContent[](size);
        (bytes32 root,) = TestHelper.getMerklePartsPacks(packsContent, 0);

        ERC1155PackHack packHack = new ERC1155PackHack(address(holder));
        packHack.initialize(owner, "name", "baseURI", "contractURI", address(this), 0, address(0), bytes32(0));

        vm.prank(owner);
        packHack.setPacksContent(root, size, 0);

        pack = packHack;

        // Mark all claimed except one
        packHack.setAllExceptOneClaimed(unclaimedIdx);

        // Mint pack to user
        vm.prank(owner);
        pack.mint(user, 0, 1, "pack");

        // Commit
        vm.prank(user);
        pack.commit(0);

        // Reveal
        vm.roll(block.number + 3);
        uint256 revealIdx = pack.getRevealIdx(user, 0);
        (, bytes32[] memory proof) = TestHelper.getMerklePartsPacks(packsContent, revealIdx);
        IERC1155Pack.PackContent memory packContent = packsContent[unclaimedIdx];
        pack.reveal(user, packContent, proof, 0);

        // Validate amounts sent
        for (uint256 i = 0; i < packContent.tokenAddresses.length; i++) {
            for (uint256 j = 0; j < packContent.tokenIds[i].length; j++) {
                vm.assertEq(token.balanceOf(user, packContent.tokenIds[i][j]), packContent.amounts[i][j]);
            }
        }
    }

    function testRevealInvalidPackContent(
        address user
    ) public {
        assumeSafeAddress(user);
        uint256 revealIdx = _getRevealIdx(user);

        vm.assume(revealIdx > 0);

        (, bytes32[] memory proof) = TestHelper.getMerklePartsPacks(packsContent, revealIdx);

        IERC1155Pack.PackContent memory packContent = packsContent[revealIdx - 1];

        vm.expectRevert(IERC1155Pack.InvalidProof.selector);
        pack.reveal(user, packContent, proof, 0);
    }

    function testRevealInvalidRevealIdx(
        address user
    ) public {
        assumeSafeAddress(user);
        uint256 revealIdx = _getRevealIdx(user);

        vm.assume(revealIdx > 0);

        (, bytes32[] memory proof) = TestHelper.getMerklePartsPacks(packsContent, revealIdx - 1);

        IERC1155Pack.PackContent memory packContent = packsContent[revealIdx];

        vm.expectRevert(IERC1155Pack.InvalidProof.selector);
        pack.reveal(user, packContent, proof, 0);
    }

    function testRevealAfterAllOpened(
        address user
    ) public {
        assumeSafeAddress(user);

        uint256 packSupply = pack.supply(0);

        bool[] memory revealed = new bool[](packSupply);
        for (uint256 i = 0; i < packSupply; i++) {
            uint256 revealIdx = _getRevealIdx(user);
            vm.assertEq(revealed[revealIdx], false);

            (, bytes32[] memory proof) = TestHelper.getMerklePartsPacks(packsContent, revealIdx);

            IERC1155Pack.PackContent memory packContent = packsContent[revealIdx];

            pack.reveal(user, packContent, proof, 0);
            revealed[revealIdx] = true;
        }
        _commit(user);
        vm.roll(block.number + 3);

        vm.expectRevert(IERC1155Pack.AllPacksOpened.selector);
        pack.getRevealIdx(user, 0);
    }

    function testRevealReentryAttack() public {
        vm.prank(owner);
        pack.mint(address(reentryAttacker), 0, 1, "pack");

        reentryAttacker.commit();

        vm.roll(block.number + 3);
        uint256 revealIdx = pack.getRevealIdx(address(reentryAttacker), 0);

        (, bytes32[] memory proof) = TestHelper.getMerklePartsPacks(packsContent, revealIdx);

        IERC1155Pack.PackContent memory packContent = packsContent[revealIdx];

        reentryAttacker.setPackAndProof(proof, packContent);

        for (uint256 i = 0; i < packContent.tokenAddresses.length; i++) {
            if (packContent.isERC721[i]) {
                continue;
            }
            uint256[] memory tokenIds = packContent.tokenIds[i];
            uint256[] memory amounts = packContent.amounts[i];
            vm.expectEmit(true, true, true, true);
            emit ERC1155Holder.ClaimAddedBatch(
                address(reentryAttacker), address(packContent.tokenAddresses[i]), tokenIds, amounts
            );
        }
        vm.expectEmit(true, true, true, true);
        emit IERC1155Pack.Reveal(address(reentryAttacker), 0);
        pack.reveal(address(reentryAttacker), packContent, proof, 0);

        // Error caught and tokens stored in holder
        for (uint256 i = 0; i < packContent.tokenAddresses.length; i++) {
            if (packContent.isERC721[i]) {
                continue;
            }
            uint256[] memory tokenIds = packContent.tokenIds[i];
            uint256[] memory amounts = packContent.amounts[i];
            for (uint256 j = 0; j < tokenIds.length; j++) {
                vm.assertEq(
                    IERC1155(address(packContent.tokenAddresses[i])).balanceOf(address(reentryAttacker), tokenIds[j]), 0
                );
                vm.assertEq(
                    IERC1155(address(packContent.tokenAddresses[i])).balanceOf(address(holder), tokenIds[j]), amounts[j]
                );
                vm.assertEq(
                    holder.claims(address(reentryAttacker), address(packContent.tokenAddresses[i]), tokenIds[j]),
                    amounts[j]
                );
            }
        }
    }

    function testCantRefundAfterReveal(
        address user
    ) public {
        assumeSafeAddress(user);
        uint256 revealIdx = _getRevealIdx(user);

        (, bytes32[] memory proof) = TestHelper.getMerklePartsPacks(packsContent, revealIdx);

        IERC1155Pack.PackContent memory packContent = packsContent[revealIdx];

        pack.reveal(user, packContent, proof, 0);

        vm.expectRevert(IERC1155Pack.NoCommit.selector);
        pack.refundPack(user, 0);
    }

    // Common functions

    function _preparePacksContent() internal {
        packsContent = new IERC1155Pack.PackContent[](4);

        // Multiple tokens on single address
        packsContent[0].tokenAddresses = new address[](1);
        packsContent[0].tokenAddresses[0] = address(token);
        packsContent[0].isERC721 = new bool[](1);
        packsContent[0].isERC721[0] = false;
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
        packsContent[1].isERC721 = new bool[](1);
        packsContent[1].isERC721[0] = false;
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
        packsContent[2].isERC721 = new bool[](2);
        packsContent[2].isERC721[0] = false;
        packsContent[2].isERC721[1] = false;
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

        // single token on single address ERC721
        packsContent[3].tokenAddresses = new address[](1);
        packsContent[3].tokenAddresses[0] = address(token721);
        packsContent[3].isERC721 = new bool[](1);
        packsContent[3].isERC721[0] = true;
        packsContent[3].tokenIds = new uint256[][](1);
        packsContent[3].tokenIds[0] = new uint256[](2);
        packsContent[3].tokenIds[0][0] = 1;
        packsContent[3].tokenIds[0][1] = 2;
        packsContent[3].amounts = new uint256[][](1);
        packsContent[3].amounts[0] = new uint256[](2);
        packsContent[3].amounts[0][0] = 1;
        packsContent[3].amounts[0][1] = 1;
    }

    function _commit(
        address user
    ) internal {
        vm.prank(owner);
        pack.mint(user, 0, 1, "pack");

        vm.prank(user);
        pack.commit(0);
    }

    function _getRevealIdx(
        address user
    ) internal returns (uint256 revealIdx) {
        _commit(user);
        vm.roll(block.number + 3);
        revealIdx = pack.getRevealIdx(user, 0);
    }

}
