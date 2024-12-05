// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {TestHelper} from "../../../TestHelper.sol";

import {ERC1155OperatorEnforced} from "src/tokens/ERC1155/presets/operator-enforced/ERC1155OperatorEnforced.sol";
import {ERC1155OperatorEnforcedFactory} from
    "src/tokens/ERC1155/presets/operator-enforced/ERC1155OperatorEnforcedFactory.sol";
import {OperatorAllowlistEnforcementErrors} from "src/tokens/common/immutable/OperatorAllowlistEnforcementErrors.sol";
import {IERC1155ItemsSignals} from "src/tokens/ERC1155/presets/items/IERC1155Items.sol";
import {OperatorAllowlistMock} from "test/_mocks/OperatorAllowlistMock.sol";
import {WalletMock} from "test/_mocks/WalletMock.sol";

contract ERC1155OperatorEnforcedTest is TestHelper, OperatorAllowlistEnforcementErrors, IERC1155ItemsSignals {
    ERC1155OperatorEnforcedFactory private factory;
    ERC1155OperatorEnforced private token;
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

        factory = new ERC1155OperatorEnforcedFactory(address(this));
        token = ERC1155OperatorEnforced(
            factory.deploy(
                proxyOwner, owner, "name", "baseURI", "contractURI", address(this), 0, address(operatorAllowlist)
            )
        );
    }

    function testReinitializeFails() public {
        vm.expectRevert(InvalidInitialization.selector);
        token.initialize(owner, "name", "baseURI", "contractURI", address(this), 0, address(operatorAllowlist));
        vm.expectRevert(InvalidInitialization.selector);
        token.initialize(owner, "name", "baseURI", "contractURI", address(this), 0);
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
        checkSelectorCollision(0xe8a3d485); // contractURI()
        checkSelectorCollision(0x248a9ca3); // getRoleAdmin(bytes32)
        checkSelectorCollision(0x9010d07c); // getRoleMember(bytes32,uint256)
        checkSelectorCollision(0xca15c873); // getRoleMemberCount(bytes32)
        checkSelectorCollision(0x2f2ff15d); // grantRole(bytes32,address)
        checkSelectorCollision(0x91d14854); // hasRole(bytes32,address)
        checkSelectorCollision(0xf8954818); // initialize(address,string,string,string,address,uint96)
        checkSelectorCollision(0x36e678f8); // initialize(address,string,string,string,address,uint96,address)
        checkSelectorCollision(0xe985e9c5); // isApprovedForAll(address,address)
        checkSelectorCollision(0x731133e9); // mint(address,uint256,uint256,bytes)
        checkSelectorCollision(0x06fdde03); // name()
        checkSelectorCollision(0x29326f29); // operatorAllowlist()
        checkSelectorCollision(0x36568abe); // renounceRole(bytes32,address)
        checkSelectorCollision(0xd547741f); // revokeRole(bytes32,address)
        checkSelectorCollision(0x2a55205a); // royaltyInfo(uint256,uint256)
        checkSelectorCollision(0x2eb2c2d6); // safeBatchTransferFrom(address,address,uint256[],uint256[],bytes)
        checkSelectorCollision(0xf242432a); // safeTransferFrom(address,address,uint256,uint256,bytes)
        checkSelectorCollision(0xa22cb465); // setApprovalForAll(address,bool)
        checkSelectorCollision(0x7e518ec8); // setBaseMetadataURI(string)
        checkSelectorCollision(0x0b5ee006); // setContractName(string)
        checkSelectorCollision(0x938e3d7b); // setContractURI(string)
        checkSelectorCollision(0x04634d8d); // setDefaultRoyalty(address,uint96)
        checkSelectorCollision(0xe4e18f6d); // setOperatorAllowlistRegistry(address)
        checkSelectorCollision(0x5944c753); // setTokenRoyalty(uint256,address,uint96)
        checkSelectorCollision(0x01ffc9a7); // supportsInterface(bytes4)
        checkSelectorCollision(0x2693ebf2); // tokenSupply(uint256)
        checkSelectorCollision(0x18160ddd); // totalSupply()
        checkSelectorCollision(0x0e89341c); // uri(uint256)
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
            _proxyOwner, tokenOwner, str, str, str, royaltyReceiver, royaltyFeeNumerator, address(operatorAllowlist)
        );
        address predictedAddr = factory.determineAddress(
            _proxyOwner, tokenOwner, str, str, str, royaltyReceiver, royaltyFeeNumerator, address(operatorAllowlist)
        );
        assertEq(deployedAddr, predictedAddr);
    }

    //
    // Transfers
    //
    function testOperatorEnforcedMintToWallet() public {
        vm.prank(owner);
        token.mint(address(wallet), 1, 1, "");

        assertEq(token.balanceOf(address(wallet), 1), 1);
    }

    function testOperatorEnforcedSetApprovalForAll() public {
        vm.prank(owner);
        token.mint(address(wallet), 1, 1, "");

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
        token.mint(address(wallet), 1, 1, "");

        WalletMock receiver = new WalletMock();

        // Set valid approvals
        operatorAllowlist.setAllowlisted(address(this), true);
        operatorAllowlist.setAllowlisted(address(wallet), true);
        vm.prank(address(wallet));
        token.setApprovalForAll(address(this), true);

        // Clear operator allowlist
        operatorAllowlist.setAllowlisted(address(this), false);
        operatorAllowlist.setAllowlisted(address(wallet), false);

        vm.expectRevert(abi.encodeWithSelector(CallerNotInAllowlist.selector, address(this)));
        token.safeTransferFrom(address(wallet), address(receiver), 1, 1, "");

        // Approve this contract
        operatorAllowlist.setAllowlisted(address(this), true);
        vm.expectRevert(abi.encodeWithSelector(TransferFromNotInAllowlist.selector, address(wallet)));
        token.safeTransferFrom(address(wallet), address(receiver), 1, 1, "");

        // Approve wallet
        operatorAllowlist.setAllowlisted(address(wallet), true);
        vm.expectRevert(abi.encodeWithSelector(TransferToNotInAllowlist.selector, address(receiver)));
        token.safeTransferFrom(address(wallet), address(receiver), 1, 1, "");

        // Approve receiver
        operatorAllowlist.setAllowlisted(address(receiver), true);
        token.safeTransferFrom(address(wallet), address(receiver), 1, 1, "");
    }

    function testOperatorEnforcedSafeTransferFromWithOperator() public {
        vm.prank(owner);
        token.mint(address(wallet), 1, 1, "");

        WalletMock receiver = new WalletMock();

        // Set valid approvals
        operatorAllowlist.setAllowlisted(address(this), true);
        operatorAllowlist.setAllowlisted(address(wallet), true);
        vm.prank(address(wallet));
        token.setApprovalForAll(address(this), true);

        // Clear operator allowlist
        operatorAllowlist.setAllowlisted(address(this), false);
        operatorAllowlist.setAllowlisted(address(wallet), false);

        vm.expectRevert(abi.encodeWithSelector(CallerNotInAllowlist.selector, address(this)));
        token.safeTransferFrom(address(wallet), address(receiver), 1, 1, "");

        // Approve this contract
        operatorAllowlist.setAllowlisted(address(this), true);
        vm.expectRevert(abi.encodeWithSelector(TransferFromNotInAllowlist.selector, address(wallet)));
        token.safeTransferFrom(address(wallet), address(receiver), 1, 1, "");

        // Approve wallet
        operatorAllowlist.setAllowlisted(address(wallet), true);
        vm.expectRevert(abi.encodeWithSelector(TransferToNotInAllowlist.selector, address(receiver)));
        token.safeTransferFrom(address(wallet), address(receiver), 1, 1, "");

        // Approve receiver
        operatorAllowlist.setAllowlisted(address(receiver), true);
        token.safeTransferFrom(address(wallet), address(receiver), 1, 1, "");
    }

    function testOperatorEnforcedSafeBatchTransferFromWithOperator() public {
        // Mint multiple tokens to the wallet
        vm.prank(owner);
        token.mint(address(wallet), 1, 1, "");
        vm.prank(owner);
        token.mint(address(wallet), 2, 2, "");

        WalletMock receiver = new WalletMock();

        // Prepare batch transfer arrays
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1;
        amounts[1] = 2;

        // Set valid approvals
        operatorAllowlist.setAllowlisted(address(this), true);
        operatorAllowlist.setAllowlisted(address(wallet), true);
        vm.prank(address(wallet));
        token.setApprovalForAll(address(this), true);

        // Clear operator allowlist
        operatorAllowlist.setAllowlisted(address(this), false);
        operatorAllowlist.setAllowlisted(address(wallet), false);

        // Test caller not in allowlist
        vm.expectRevert(abi.encodeWithSelector(CallerNotInAllowlist.selector, address(this)));
        token.safeBatchTransferFrom(address(wallet), address(receiver), ids, amounts, "");

        // Test transfer from not in allowlist
        operatorAllowlist.setAllowlisted(address(this), true);
        vm.expectRevert(abi.encodeWithSelector(TransferFromNotInAllowlist.selector, address(wallet)));
        token.safeBatchTransferFrom(address(wallet), address(receiver), ids, amounts, "");

        // Test transfer to not in allowlist
        operatorAllowlist.setAllowlisted(address(wallet), true);
        vm.expectRevert(abi.encodeWithSelector(TransferToNotInAllowlist.selector, address(receiver)));
        token.safeBatchTransferFrom(address(wallet), address(receiver), ids, amounts, "");

        // Test successful batch transfer
        operatorAllowlist.setAllowlisted(address(receiver), true);
        token.safeBatchTransferFrom(address(wallet), address(receiver), ids, amounts, "");

        // Verify balances
        assertEq(token.balanceOf(address(receiver), 1), 1);
        assertEq(token.balanceOf(address(receiver), 2), 2);
        assertEq(token.balanceOf(address(wallet), 1), 0);
        assertEq(token.balanceOf(address(wallet), 2), 0);
    }
}
