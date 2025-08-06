// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

// solhint-disable func-name-mixedcase

import { Test } from "forge-std/Test.sol";

import { IAccessControl } from "src/modular/modules/accessControl/IAccessControl.sol";
import { ModularProxy } from "src/modular/modules/modularProxy/ModularProxy.sol";
import { ModularProxyFactory } from "src/modular/modules/modularProxy/ModularProxyFactory.sol";
import { ERC2981Controlled } from "src/modular/modules/tokens/royalty/ERC2981Controlled.sol";

contract ERC2981ControlledTest is Test {

    ERC2981Controlled public erc2981Controlled;

    bytes32 public constant ROYALTY_ADMIN_ROLE = keccak256("ROYALTY_ADMIN_ROLE");

    function setUp() public {
        ERC2981Controlled erc2981ControlledImpl = new ERC2981Controlled();
        ModularProxyFactory factory = new ModularProxyFactory();
        ModularProxy proxy = factory.deploy(0, address(erc2981ControlledImpl), address(this));
        erc2981Controlled = ERC2981Controlled(address(proxy));
    }

    modifier withRole() {
        erc2981Controlled.onAttachModule(abi.encodePacked(address(this)));
        _;
    }

    function test_erc2981Controlled_onAddExtension_adminNoDefaults(
        address admin,
        uint256 tokenId,
        uint256 salePrice
    ) public {
        vm.expectEmit(true, true, true, true, address(erc2981Controlled));
        emit IAccessControl.RoleGranted(ROYALTY_ADMIN_ROLE, admin, address(this));
        bytes memory initData = abi.encodePacked(admin);
        erc2981Controlled.onAttachModule(initData);

        (address actualReceiver, uint256 actualRoyaltyAmount) = erc2981Controlled.royaltyInfo(tokenId, salePrice);
        assertEq(actualReceiver, address(0));
        assertEq(actualRoyaltyAmount, 0);
    }

    function test_erc2981Controlled_onAddExtension_adminAndDefaults(
        address admin,
        address receiver,
        uint96 royaltyBps,
        uint256 tokenId
    ) public {
        vm.assume(receiver != address(0));

        vm.expectEmit(true, true, true, true, address(erc2981Controlled));
        emit IAccessControl.RoleGranted(ROYALTY_ADMIN_ROLE, admin, address(this));
        bytes memory initData = abi.encodePacked(admin, receiver, royaltyBps);
        erc2981Controlled.onAttachModule(initData);

        (address actualReceiver, uint256 actualRoyaltyAmount) = erc2981Controlled.royaltyInfo(tokenId, 10000);
        assertEq(actualReceiver, receiver);
        assertEq(actualRoyaltyAmount, royaltyBps);
    }

    function test_erc2981Controlled_setDefaultRoyalty(
        address receiver,
        uint96 royaltyBps,
        uint256 tokenId
    ) public withRole {
        vm.assume(receiver != address(0));

        erc2981Controlled.setDefaultRoyalty(receiver, royaltyBps);
        (address actualReceiver, uint256 royaltyAmount) = erc2981Controlled.royaltyInfo(tokenId, 10000);
        assertEq(actualReceiver, receiver);
        assertEq(royaltyAmount, royaltyBps);
    }

    function test_erc2981Controlled_setTokenRoyalty(
        address receiver,
        uint96 royaltyBps,
        uint256 tokenId
    ) public withRole {
        vm.assume(receiver != address(0));

        erc2981Controlled.setTokenRoyalty(tokenId, receiver, royaltyBps);
        (address actualReceiver, uint256 royaltyAmount) = erc2981Controlled.royaltyInfo(tokenId, 10000);
        assertEq(actualReceiver, receiver);
        assertEq(royaltyAmount, royaltyBps);
    }

}
