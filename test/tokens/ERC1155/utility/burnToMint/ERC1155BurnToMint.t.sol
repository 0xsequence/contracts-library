// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {TestHelper} from "../../../../TestHelper.sol";

import {ERC1155Items} from "src/tokens/ERC1155/presets/items/ERC1155Items.sol";
import {ERC1155BurnToMint, TokenRequirements} from "src/tokens/ERC1155/utility/burnToMint/ERC1155BurnToMint.sol";

contract ERC1155BurnToMintTest is TestHelper {
    ERC1155Items private token;
    ERC1155BurnToMint private minter;

    address private owner;

    function setUp() public {
        owner = makeAddr("owner");

        token = new ERC1155Items();
        token.initialize(owner, "test", "ipfs://", "ipfs://", owner, 0);

        minter = new ERC1155BurnToMint(address(token), owner);

        // Set minter ro le on minter
        vm.prank(owner);
        token.grantRole(keccak256("MINTER_ROLE"), address(minter));
    }

    function testMintOpen(address holder, uint256 tokenId, uint256 amount) public {
        assumeSafeAddress(holder);
        amount = _bound(amount, 1, 100);

        vm.label(holder, "holder");

        vm.prank(owner);
        minter.mintOpen(holder, tokenId, amount);
        assertEq(token.balanceOf(holder, tokenId), amount);
    }

    function testBurnToMint(
        address holder,
        uint256 mintId,
        uint256[] memory burnIds,
        uint256[] memory burnAmounts,
        uint256[] memory holdIds,
        uint256[] memory holdAmounts
    )
        public
    {
        vm.assume(burnIds.length > 0); // At least one burn token
        assumeSafeAddress(holder);
        vm.label(holder, "holder");

        (burnIds, burnAmounts) = _fixInputIdArray(burnIds, burnAmounts, 3, mintId);
        (holdIds, holdAmounts) = _fixInputIdArray(holdIds, holdAmounts, 3, mintId);

        vm.startPrank(owner);
        // Set the burn requirements
        minter.setMintRequirements(mintId, burnIds, burnAmounts, holdIds, holdAmounts);

        // Mint required tokens for holding
        token.batchMint(holder, holdIds, holdAmounts, "");
        address[] memory _owners = new address[](burnIds.length);
        for (uint256 i = 0; i < burnIds.length; i++) {
            _owners[i] = holder;
        }
        uint256[] memory expectedEndBalances = token.balanceOfBatch(_owners, burnIds);

        // Mint required tokens for burning
        token.batchMint(holder, burnIds, burnAmounts, "");

        vm.stopPrank();

        // Send tokens for burning
        bytes memory data = abi.encode(mintId);
        vm.prank(holder);
        token.safeBatchTransferFrom(holder, address(minter), burnIds, burnAmounts, data);

        // Check minted tokens
        assertEq(token.balanceOf(holder, mintId), 1);
        // Check burned tokens
        assertEq(token.balanceOfBatch(_owners, burnIds), expectedEndBalances);
    }

    function testGetMintRequirements(
        uint256 mintId,
        uint256[] memory burnIds,
        uint256[] memory burnAmounts,
        uint256[] memory holdIds,
        uint256[] memory holdAmounts) public {
        vm.assume(burnIds.length > 0); // At least one burn token

        (burnIds, burnAmounts) = _fixInputIdArray(burnIds, burnAmounts, 3, mintId);
        (holdIds, holdAmounts) = _fixInputIdArray(holdIds, holdAmounts, 3, mintId);

        // Set the burn requirements
        vm.prank(owner);
        minter.setMintRequirements(mintId, burnIds, burnAmounts, holdIds, holdAmounts);

        // Get mint requirements
        (uint256[] memory burnIdsOut, uint256[] memory burnAmountsOut, uint256[] memory holdIdsOut, uint256[] memory holdAmountsOut) = minter.getMintRequirements(mintId);

        assertEq(burnIdsOut.length, burnIds.length);
        assertEq(burnAmountsOut.length, burnAmounts.length);
        assertEq(holdIdsOut.length, holdIds.length);
        assertEq(holdAmountsOut.length, holdAmounts.length);

        for (uint256 i = 0; i < burnIds.length; i++) {
            assertEq(burnIdsOut[i], burnIds[i]);
            assertEq(burnAmountsOut[i], burnAmounts[i]);
        }
        for (uint256 i = 0; i < holdIds.length; i++) {
            assertEq(holdIdsOut[i], holdIds[i]);
            assertEq(holdAmountsOut[i], holdAmounts[i]);
        }
    }

    function _fixInputIdArray(uint256[] memory idsInput, uint256[] memory amountsInput, uint256 size, uint256 noMatch) internal pure returns (uint256[] memory, uint256[] memory amounts) {
        if (idsInput.length > size) {
            assembly {
                mstore(idsInput, size)
            }
        }
        assumeNoDuplicates(idsInput);

        amounts = new uint256[](idsInput.length);
        for (uint256 i = 0; i < idsInput.length; i++) {
            vm.assume(noMatch != idsInput[i]); // No matching this id
            amounts[i] = _bound(amountsInput.length > i ? amountsInput[i] : 1, 1, 100); // Max size
        }

        return (idsInput, amounts);
    }
}
