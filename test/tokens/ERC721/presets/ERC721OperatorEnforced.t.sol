// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {TestHelper} from "../../../TestHelper.sol";

import {ERC721OperatorEnforced} from "src/tokens/ERC721/presets/operator-enforced/ERC721OperatorEnforced.sol";
import {ERC721OperatorEnforcedFactory} from
    "src/tokens/ERC721/presets/operator-enforced/ERC721OperatorEnforcedFactory.sol";
import {OperatorAllowlistEnforcementErrors} from "src/tokens/common/immutable/OperatorAllowlistEnforcementErrors.sol";
import {IERC721ItemsSignals} from "src/tokens/ERC721/presets/items/IERC721Items.sol";
import {OperatorAllowlistMock} from "test/_mocks/OperatorAllowlistMock.sol";
import {WalletMock} from "test/_mocks/WalletMock.sol";

contract ERC721OperatorEnforcedTest is TestHelper, OperatorAllowlistEnforcementErrors, IERC721ItemsSignals {
    ERC721OperatorEnforcedFactory private factory;
    ERC721OperatorEnforced private token;
    OperatorAllowlistMock private operatorAllowlist;
    WalletMock private wallet;
    address private proxyOwner;
    address private owner;

    function setUp() public {
        owner = makeAddr("owner");
        proxyOwner = makeAddr("proxyOwner");

        vm.deal(address(this), 100 ether);
        vm.deal(owner, 100 ether);

        operatorAllowlist = new OperatorAllowlistMock();
        wallet = new WalletMock();

        factory = new ERC721OperatorEnforcedFactory(address(this));
        token = ERC721OperatorEnforced(
            factory.deploy(
                proxyOwner,
                owner,
                "name",
                "symbol",
                "baseURI",
                "contractURI",
                address(this),
                0,
                address(operatorAllowlist)
            )
        );
    }

    function testReinitializeFails() public {
        vm.expectRevert(InvalidInitialization.selector);
        token.initialize(
            owner, "name", "symbol", "baseURI", "contractURI", address(this), 0, address(operatorAllowlist)
        );
        vm.expectRevert(InvalidInitialization.selector);
        token.initialize(owner, "name", "symbol", "baseURI", "contractURI", address(this), 0);
    }

    /**
     * Test all public selectors for collisions against the proxy admin functions.
     * @dev yarn ts-node scripts/outputSelectors.ts
     */
    function testSelectorCollision() public pure {
        checkSelectorCollision(0xa217fddf); // DEFAULT_ADMIN_ROLE()
        checkSelectorCollision(0x095ea7b3); // approve(address,uint256)
        checkSelectorCollision(0x70a08231); // balanceOf(address)
        checkSelectorCollision(0xdc8e92ea); // batchBurn(uint256[])
        checkSelectorCollision(0x42966c68); // burn(uint256)
        checkSelectorCollision(0xe8a3d485); // contractURI()
        checkSelectorCollision(0xc23dc68f); // explicitOwnershipOf(uint256)
        checkSelectorCollision(0x5bbb2177); // explicitOwnershipsOf(uint256[])
        checkSelectorCollision(0x081812fc); // getApproved(uint256)
        checkSelectorCollision(0x248a9ca3); // getRoleAdmin(bytes32)
        checkSelectorCollision(0x9010d07c); // getRoleMember(bytes32,uint256)
        checkSelectorCollision(0xca15c873); // getRoleMemberCount(bytes32)
        checkSelectorCollision(0x2f2ff15d); // grantRole(bytes32,address)
        checkSelectorCollision(0x91d14854); // hasRole(bytes32,address)
        checkSelectorCollision(0x98dd69c8); // initialize(address,string,string,string,string,address,uint96)
        checkSelectorCollision(0x9b1b4779); // initialize(address,string,string,string,string,address,uint96,address)
        checkSelectorCollision(0xe985e9c5); // isApprovedForAll(address,address)
        checkSelectorCollision(0x40c10f19); // mint(address,uint256)
        checkSelectorCollision(0x06fdde03); // name()
        checkSelectorCollision(0x29326f29); // operatorAllowlist()
        checkSelectorCollision(0x6352211e); // ownerOf(uint256)
        checkSelectorCollision(0x36568abe); // renounceRole(bytes32,address)
        checkSelectorCollision(0xd547741f); // revokeRole(bytes32,address)
        checkSelectorCollision(0x2a55205a); // royaltyInfo(uint256,uint256)
        checkSelectorCollision(0x42842e0e); // safeTransferFrom(address,address,uint256)
        checkSelectorCollision(0xb88d4fde); // safeTransferFrom(address,address,uint256,bytes)
        checkSelectorCollision(0xa22cb465); // setApprovalForAll(address,bool)
        checkSelectorCollision(0x7e518ec8); // setBaseMetadataURI(string)
        checkSelectorCollision(0x938e3d7b); // setContractURI(string)
        checkSelectorCollision(0x04634d8d); // setDefaultRoyalty(address,uint96)
        checkSelectorCollision(0x5a446215); // setNameAndSymbol(string,string)
        checkSelectorCollision(0xe4e18f6d); // setOperatorAllowlistRegistry(address)
        checkSelectorCollision(0x5944c753); // setTokenRoyalty(uint256,address,uint96)
        checkSelectorCollision(0x01ffc9a7); // supportsInterface(bytes4)
        checkSelectorCollision(0x95d89b41); // symbol()
        checkSelectorCollision(0xc87b56dd); // tokenURI(uint256)
        checkSelectorCollision(0x8462151c); // tokensOfOwner(address)
        checkSelectorCollision(0x99a2557a); // tokensOfOwnerIn(address,uint256,uint256)
        checkSelectorCollision(0x18160ddd); // totalSupply()
        checkSelectorCollision(0x23b872dd); // transferFrom(address,address,uint256)
    }

    function testFactoryDetermineAddress(
        address _proxyOwner,
        address tokenOwner,
        string memory str,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator
    ) public {
        assumeNotZeroAddress(_proxyOwner);
        assumeNotZeroAddress(tokenOwner);
        assumeNotZeroAddress(royaltyReceiver);
        royaltyFeeNumerator = uint96(bound(royaltyFeeNumerator, 0, 10_000));
        address deployedAddr = factory.deploy(
            _proxyOwner,
            tokenOwner,
            str,
            str,
            str,
            str,
            royaltyReceiver,
            royaltyFeeNumerator,
            address(operatorAllowlist)
        );
        address predictedAddr = factory.determineAddress(
            _proxyOwner,
            tokenOwner,
            str,
            str,
            str,
            str,
            royaltyReceiver,
            royaltyFeeNumerator,
            address(operatorAllowlist)
        );
        assertEq(deployedAddr, predictedAddr);
    }

    //
    // Transfers
    //
    function testOperatorEnforcedMintToWallet() public {
        vm.prank(owner);
        token.mint(address(wallet), 1);

        assertEq(token.ownerOf(0), address(wallet));
    }

    function testOperatorEnforcedApproval() public {
        vm.prank(owner);
        token.mint(address(wallet), 1);

        vm.expectRevert(abi.encodeWithSelector(ApproverNotInAllowlist.selector, address(wallet)));
        vm.prank(address(wallet));
        token.approve(address(this), 0);

        // Approve wallet
        operatorAllowlist.setAllowlisted(address(wallet), true);

        vm.expectRevert(abi.encodeWithSelector(ApproveTargetNotInAllowlist.selector, address(this)));
        vm.prank(address(wallet));
        token.approve(address(this), 0);

        // Approve this contract
        operatorAllowlist.setAllowlisted(address(this), true);
        vm.prank(address(wallet));
        token.approve(address(this), 0);
    }

    function testOperatorEnforcedSetApprovalForAll() public {
        vm.prank(owner);
        token.mint(address(wallet), 1);

        vm.expectRevert(abi.encodeWithSelector(ApproverNotInAllowlist.selector, address(wallet)));
        vm.prank(address(wallet));
        token.setApprovalForAll(address(this), true);

        // Approve wallet
        operatorAllowlist.setAllowlisted(address(wallet), true);

        vm.expectRevert(abi.encodeWithSelector(ApproveTargetNotInAllowlist.selector, address(this)));
        vm.prank(address(wallet));
        token.setApprovalForAll(address(this), true);

        // Approve this contract
        operatorAllowlist.setAllowlisted(address(this), true);
        vm.prank(address(wallet));
        token.setApprovalForAll(address(this), true);
    }

    function testOperatorEnforcedTransferFromWithOperator() public {
        vm.prank(owner);
        token.mint(address(wallet), 1);

        WalletMock receiver = new WalletMock();

        // Set valid approvals
        operatorAllowlist.setAllowlisted(address(this), true);
        operatorAllowlist.setAllowlisted(address(wallet), true);
        vm.prank(address(wallet));
        token.approve(address(this), 0);

        // Clear operator allowlist
        operatorAllowlist.setAllowlisted(address(this), false);
        operatorAllowlist.setAllowlisted(address(wallet), false);

        vm.expectRevert(abi.encodeWithSelector(CallerNotInAllowlist.selector, address(this)));
        token.transferFrom(address(wallet), address(receiver), 0);

        // Approve this contract
        operatorAllowlist.setAllowlisted(address(this), true);
        vm.expectRevert(abi.encodeWithSelector(TransferFromNotInAllowlist.selector, address(wallet)));
        token.transferFrom(address(wallet), address(receiver), 0);

        // Approve wallet
        operatorAllowlist.setAllowlisted(address(wallet), true);
        vm.expectRevert(abi.encodeWithSelector(TransferToNotInAllowlist.selector, address(receiver)));
        token.transferFrom(address(wallet), address(receiver), 0);

        // Approve receiver
        operatorAllowlist.setAllowlisted(address(receiver), true);
        token.transferFrom(address(wallet), address(receiver), 0);
    }

    function testOperatorEnforcedSafeTransferFromWithOperator() public {
        vm.prank(owner);
        token.mint(address(wallet), 1);

        WalletMock receiver = new WalletMock();

        // Set valid approvals
        operatorAllowlist.setAllowlisted(address(this), true);
        operatorAllowlist.setAllowlisted(address(wallet), true);
        vm.prank(address(wallet));
        token.approve(address(this), 0);

        // Clear operator allowlist
        operatorAllowlist.setAllowlisted(address(this), false);
        operatorAllowlist.setAllowlisted(address(wallet), false);

        vm.expectRevert(abi.encodeWithSelector(CallerNotInAllowlist.selector, address(this)));
        token.safeTransferFrom(address(wallet), address(receiver), 0);

        // Approve this contract
        operatorAllowlist.setAllowlisted(address(this), true);
        vm.expectRevert(abi.encodeWithSelector(TransferFromNotInAllowlist.selector, address(wallet)));
        token.safeTransferFrom(address(wallet), address(receiver), 0);

        // Approve wallet
        operatorAllowlist.setAllowlisted(address(wallet), true);
        vm.expectRevert(abi.encodeWithSelector(TransferToNotInAllowlist.selector, address(receiver)));
        token.safeTransferFrom(address(wallet), address(receiver), 0);

        // Approve receiver
        operatorAllowlist.setAllowlisted(address(receiver), true);
        token.safeTransferFrom(address(wallet), address(receiver), 0);
    }
}
