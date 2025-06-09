// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.24;

import {TestHelper} from "../../../TestHelper.sol";
import {WalletMock} from "../../../_mocks/WalletMock.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {ERC721CItems} from "src/tokens/ERC721/presets/c_items/ERC721CItems.sol";
import {ERC721CItemsFactory} from "src/tokens/ERC721/presets/c_items/ERC721CItemsFactory.sol";

import {CreatorTokenTransferValidatorConfiguration} from "@limitbreak/creator-token-standards/utils/CreatorTokenTransferValidatorConfiguration.sol";
import {CreatorTokenTransferValidator} from "@limitbreak/creator-token-standards/utils/CreatorTokenTransferValidator.sol";
import {EOARegistry} from "@limitbreak/creator-token-standards/utils/EOARegistry.sol";

contract ERC721CItemsTransfersTest is TestHelper {
    // Redeclare events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    ERC721CItems private token;
    EOARegistry private eoaRegistry;
    CreatorTokenTransferValidatorConfiguration private config;
    CreatorTokenTransferValidator private validator;

    address private proxyOwner;
    address private owner;
    address private holder;
    address private operator;
    address private blacklisted;
    address private whitelisted;
    address private wallet;

    uint256 private holderPk;
    uint256 private operatorPk;

    uint120 private listId;

    function setUp() public {
        owner = makeAddr("owner");
        proxyOwner = makeAddr("proxyOwner");
        (holder, holderPk) = makeAddrAndKey("holder");
        (operator, operatorPk) = makeAddrAndKey("operator");
        blacklisted = makeAddr("blacklisted");
        whitelisted = makeAddr("whitelisted");

        wallet = address(new WalletMock());

        vm.deal(address(this), 100 ether);
        vm.deal(owner, 100 ether);

        ERC721CItemsFactory factory = new ERC721CItemsFactory(address(this));
        token = ERC721CItems(
            factory.deploy(proxyOwner, owner, "name", "symbol", "baseURI", "contractURI", address(this), 0)
        );

        eoaRegistry = new EOARegistry();
        config = new CreatorTokenTransferValidatorConfiguration(address(this));
        config.setNativeValueToCheckPauseState(0);
        validator = new CreatorTokenTransferValidator(
            address(this), address(eoaRegistry), "CreatorTokenTransferValidator", "3", address(config)
        );

        vm.prank(owner);
        token.setTransferValidator(address(validator));

        // Sign EOAs in registry
        bytes32 hashToSign = ECDSA.toEthSignedMessageHash(bytes(eoaRegistry.MESSAGE_TO_SIGN()));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(holderPk, hashToSign);
        eoaRegistry.verifySignatureVRS(v, r, s);
        (v, r, s) = vm.sign(operatorPk, hashToSign);
        eoaRegistry.verifySignatureVRS(v, r, s);

        // Prep for transfer tests

        vm.startPrank(owner);
        token.mint(holder, 1);
        token.mint(wallet, 1);
        vm.stopPrank();

        vm.startPrank(holder);
        token.setApprovalForAll(operator, true);
        token.setApprovalForAll(blacklisted, true);
        token.setApprovalForAll(whitelisted, true);
        token.setApprovalForAll(wallet, true);
        vm.stopPrank();

        vm.startPrank(owner);
        validator.setTransferSecurityLevelOfCollection(address(token), 2, true, true, false);
        listId = validator.createList("TOKEN");
        address[] memory addressList = new address[](1);
        addressList[0] = blacklisted;
        validator.addAccountsToBlacklist(listId, addressList);
        addressList[0] = whitelisted;
        validator.addAccountsToWhitelist(listId, addressList);
        // bytes32[] memory codehashes = new bytes32[](1);
        // codehashes[0] = wallet.codehash;
        // validator.addCodeHashesToWhitelist(listId, codehashes);
        validator.applyListToCollection(address(token), listId);
        vm.stopPrank();
    }

    function _setLevel(uint8 level) private {
        vm.startPrank(owner);
        validator.setTransferSecurityLevelOfCollection(address(token), level, true, true, false);

        if (level == 5 || level == 6) {
            bytes32[] memory codehashes = new bytes32[](1);
            codehashes[0] = wallet.codehash;
            validator.addCodeHashesToWhitelist(listId, codehashes);
        }
        vm.stopPrank();
    }

    function testTransferLevelDefault() public {
        vm.prank(holder);
        token.transferFrom(holder, owner, 0);
        vm.assertEq(token.ownerOf(0), owner);
    }

    // No protection
    function testTransferLevel1OTC() public {
        _setLevel(1);

        vm.prank(holder);
        token.transferFrom(holder, operator, 0);
        vm.assertEq(token.ownerOf(0), operator);
    }
    function testTransferLevel1WalletOTC() public {
        _setLevel(1);

        vm.prank(wallet);
        token.transferFrom(wallet, operator, 1);
        vm.assertEq(token.ownerOf(1), operator);
    }
    function testTransferLevel1OTCWalletReceiver() public {
        _setLevel(1);

        vm.prank(holder);
        token.transferFrom(holder, wallet, 0);
        vm.assertEq(token.ownerOf(0), wallet);
    }
    function testTransferLevel1Operator() public {
        _setLevel(1);

        vm.prank(operator);
        token.transferFrom(holder, operator, 0);
        vm.assertEq(token.ownerOf(0), operator);
    }
    function testTransferLevel1WalletOperator() public {
        _setLevel(1);

        vm.prank(wallet);
        token.transferFrom(holder, wallet, 0);
        vm.assertEq(token.ownerOf(0), wallet);
    }

    // Blacklist + OTC
    function testTransferLevel2OTC() public {
        _setLevel(2);

        vm.prank(holder);
        token.transferFrom(holder, operator, 0);
        vm.assertEq(token.ownerOf(0), operator);
    }
    function testTransferLevel2WalletOTC() public {
        _setLevel(2);

        vm.prank(wallet);
        token.transferFrom(wallet, operator, 1);
        vm.assertEq(token.ownerOf(1), operator);
    }
    function testTransferLevel2OTCWalletReceiver() public {
        _setLevel(2);

        vm.prank(holder);
        token.transferFrom(holder, wallet, 0);
        vm.assertEq(token.ownerOf(0), wallet);
    }
    function testTransferLevel2Operator() public {
        _setLevel(2);

        vm.prank(operator);
        token.transferFrom(holder, operator, 0);
        vm.assertEq(token.ownerOf(0), operator);
    }
    function testTransferLevel2WalletOperator() public {
        _setLevel(2);

        vm.prank(wallet);
        token.transferFrom(holder, wallet, 0);
        vm.assertEq(token.ownerOf(0), wallet);
    }
    function testTransferLevel2Blacklisted() public {
        _setLevel(2);

        vm.expectRevert();
        vm.prank(blacklisted);
        token.transferFrom(holder, blacklisted, 0);
    }

    // Whitelist + OTC
    function testTransferLevel3OTC() public {
        _setLevel(3);

        vm.prank(holder);
        token.transferFrom(holder, operator, 0);
        vm.assertEq(token.ownerOf(0), operator);
    }
    function testTransferLevel3WalletOTC() public {
        _setLevel(3);

        vm.prank(wallet);
        token.transferFrom(wallet, operator, 1);
        vm.assertEq(token.ownerOf(1), operator);
    }
    function testTransferLevel3OTCWalletReceiver() public {
        _setLevel(3);

        vm.prank(holder);
        token.transferFrom(holder, wallet, 0);
        vm.assertEq(token.ownerOf(0), wallet);
    }
    function testTransferLevel3Operator() public {
        _setLevel(3);

        vm.expectRevert();
        vm.prank(operator);
        token.transferFrom(holder, operator, 0);
    }
    function testTransferLevel3WalletOperator() public {
        _setLevel(3);

        vm.expectRevert();
        vm.prank(wallet);
        token.transferFrom(holder, wallet, 0);
    }
    function testTransferLevel3Blacklisted() public {
        _setLevel(3);

        vm.expectRevert();
        vm.prank(blacklisted);
        token.transferFrom(holder, blacklisted, 0);
    }
    function testTransferLevel3Whitelisted() public {
        _setLevel(3);

        vm.prank(whitelisted);
        token.transferFrom(holder, whitelisted, 0);
        vm.assertEq(token.ownerOf(0), whitelisted);
    }

    // Whitelist + No OTC
    function testTransferLevel4OTC() public {
        _setLevel(4);

        vm.expectRevert();
        vm.prank(holder);
        token.transferFrom(holder, operator, 0);
    }
    function testTransferLevel4WalletOTC() public {
        _setLevel(4);

        vm.expectRevert();
        vm.prank(wallet);
        token.transferFrom(wallet, operator, 1);
    }
    function testTransferLevel4OTCWalletReceiver() public {
        _setLevel(4);

        vm.expectRevert();
        vm.prank(holder);
        token.transferFrom(holder, wallet, 0);
    }
    function testTransferLevel4Operator() public {
        _setLevel(4);

        vm.expectRevert();
        vm.prank(operator);
        token.transferFrom(holder, operator, 0);
    }
    function testTransferLevel4WalletOperator() public {
        _setLevel(4);

        vm.expectRevert();
        vm.prank(wallet);
        token.transferFrom(holder, wallet, 0);
    }
    function testTransferLevel4Blacklisted() public {
        _setLevel(4);

        vm.expectRevert();
        vm.prank(blacklisted);
        token.transferFrom(holder, blacklisted, 0);
    }
    function testTransferLevel4Whitelisted() public {
        _setLevel(4);

        vm.prank(whitelisted);
        token.transferFrom(holder, whitelisted, 0);
        vm.assertEq(token.ownerOf(0), whitelisted);
    }

    // Whitelist + OTC + No code receiver
    function testTransferLevel5OTC() public {
        _setLevel(5);

        vm.prank(holder);
        token.transferFrom(holder, operator, 0);
        vm.assertEq(token.ownerOf(0), operator);
    }
    function testTransferLevel5WalletOTC() public {
        _setLevel(5);

        vm.prank(wallet);
        token.transferFrom(wallet, operator, 1);
        vm.assertEq(token.ownerOf(1), operator);
    }
    function testTransferLevel5OTCWalletReceiver() public {
        _setLevel(5);

        vm.prank(holder);
        token.transferFrom(holder, wallet, 0);
        vm.assertEq(token.ownerOf(0), wallet);
    }
    function testTransferLevel5Operator() public {
        _setLevel(5);

        vm.expectRevert();
        vm.prank(operator);
        token.transferFrom(holder, operator, 0);
    }
    function testTransferLevel5WalletOperator() public {
        _setLevel(5);

        vm.expectRevert(); //FIXME This passes as code hash is whitelisted to enable Wallet OTC transfers
        vm.prank(wallet);
        token.transferFrom(holder, wallet, 0);
    }
    function testTransferLevel5Blacklisted() public {
        _setLevel(5);

        vm.expectRevert();
        vm.prank(blacklisted);
        token.transferFrom(holder, blacklisted, 0);
    }
    function testTransferLevel5Whitelisted() public {
        _setLevel(5);

        vm.prank(whitelisted);
        token.transferFrom(holder, whitelisted, 0);
        vm.assertEq(token.ownerOf(0), whitelisted);
    }

    // Whitelist + OTC + EOA Receiver
    function testTransferLevel6OTC() public {
        _setLevel(6);

        vm.prank(holder);
        token.transferFrom(holder, operator, 0);
        vm.assertEq(token.ownerOf(0), operator);
    }
    function testTransferLevel6WalletOTC() public {
        _setLevel(6);

        vm.prank(wallet);
        token.transferFrom(wallet, operator, 1);
        vm.assertEq(token.ownerOf(1), operator);
    }
    function testTransferLevel6OTCWalletReceiver() public {
        _setLevel(6);

        vm.prank(holder);
        token.transferFrom(holder, wallet, 0);
        vm.assertEq(token.ownerOf(0), wallet);
    }
    function testTransferLevel6Operator() public {
        _setLevel(6);

        vm.expectRevert();
        vm.prank(operator);
        token.transferFrom(holder, operator, 0);
    }
    function testTransferLevel6WalletOperator() public {
        _setLevel(6);

        vm.expectRevert(); //FIXME This passes as code hash is whitelisted to enable Wallet OTC transfers
        vm.prank(wallet);
        token.transferFrom(holder, wallet, 0);
    }
    function testTransferLevel6Blacklisted() public {
        _setLevel(6);

        vm.expectRevert();
        vm.prank(blacklisted);
        token.transferFrom(holder, blacklisted, 0);
    }
    function testTransferLevel6Whitelisted() public {
        _setLevel(6);

        vm.prank(whitelisted);
        token.transferFrom(holder, whitelisted, 0);
        vm.assertEq(token.ownerOf(0), whitelisted);
    }

    // Whitelist + No OTC + No code receiver
    function testTransferLevel7OTC() public {
        _setLevel(7);

        vm.expectRevert();
        vm.prank(holder);
        token.transferFrom(holder, operator, 0);
    }
    function testTransferLevel7WalletOTC() public {
        _setLevel(7);

        vm.expectRevert();
        vm.prank(wallet);
        token.transferFrom(wallet, operator, 1);
    }
    function testTransferLevel7OTCWalletReceiver() public {
        _setLevel(7);

        vm.expectRevert();
        vm.prank(holder);
        token.transferFrom(holder, wallet, 0);
    }
    function testTransferLevel7Operator() public {
        _setLevel(7);

        vm.expectRevert();
        vm.prank(operator);
        token.transferFrom(holder, operator, 0);
    }
    function testTransferLevel7WalletOperator() public {
        _setLevel(7);

        vm.expectRevert();
        vm.prank(wallet);
        token.transferFrom(holder, wallet, 0);
    }
    function testTransferLevel7Blacklisted() public {
        _setLevel(7);

        vm.expectRevert();
        vm.prank(blacklisted);
        token.transferFrom(holder, blacklisted, 0);
    }
    function testTransferLevel7Whitelisted() public {
        _setLevel(7);

        vm.prank(whitelisted);
        token.transferFrom(holder, whitelisted, 0);
        vm.assertEq(token.ownerOf(0), whitelisted);
    }

    // Whitelist + No OTC + EOA Receiver
    function testTransferLevel8OTC() public {
        _setLevel(8);

        vm.expectRevert();
        vm.prank(holder);
        token.transferFrom(holder, operator, 0);
    }
    function testTransferLevel8WalletOTC() public {
        _setLevel(8);

        vm.expectRevert();
        vm.prank(wallet);
        token.transferFrom(wallet, operator, 1);
    }
    function testTransferLevel8OTCWalletReceiver() public {
        _setLevel(8);

        vm.expectRevert();
        vm.prank(holder);
        token.transferFrom(holder, wallet, 0);
    }
    function testTransferLevel8Operator() public {
        _setLevel(8);

        vm.expectRevert();
        vm.prank(operator);
        token.transferFrom(holder, operator, 0);
    }
    function testTransferLevel8WalletOperator() public {
        _setLevel(8);

        vm.expectRevert();
        vm.prank(wallet);
        token.transferFrom(holder, wallet, 0);
    }
    function testTransferLevel8Blacklisted() public {
        _setLevel(8);

        vm.expectRevert();
        vm.prank(blacklisted);
        token.transferFrom(holder, blacklisted, 0);
    }
    function testTransferLevel8Whitelisted() public {
        _setLevel(8);

        vm.prank(whitelisted);
        token.transferFrom(holder, whitelisted, 0);
        vm.assertEq(token.ownerOf(0), whitelisted);
    }

    // Soul bound
    function testTransferLevel9OTC() public {
        _setLevel(9);

        vm.expectRevert();
        vm.prank(holder);
        token.transferFrom(holder, operator, 0);
    }
    function testTransferLevel9WalletOTC() public {
        _setLevel(9);

        vm.expectRevert();
        vm.prank(wallet);
        token.transferFrom(wallet, operator, 1);
    }
    function testTransferLevel9OTCWalletReceiver() public {
        _setLevel(9);

        vm.expectRevert();
        vm.prank(holder);
        token.transferFrom(holder, wallet, 0);
    }
    function testTransferLevel9Operator() public {
        _setLevel(9);

        vm.expectRevert();
        vm.prank(operator);
        token.transferFrom(holder, operator, 0);
    }
    function testTransferLevel9WalletOperator() public {
        _setLevel(9);

        vm.expectRevert();
        vm.prank(wallet);
        token.transferFrom(holder, wallet, 0);
    }
    function testTransferLevel9Blacklisted() public {
        _setLevel(9);

        vm.expectRevert();
        vm.prank(blacklisted);
        token.transferFrom(holder, blacklisted, 0);
    }
    function testTransferLevel9Whitelisted() public {
        _setLevel(9);

        vm.expectRevert();
        vm.prank(whitelisted);
        token.transferFrom(holder, whitelisted, 0);
    }
}
