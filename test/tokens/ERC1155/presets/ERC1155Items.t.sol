// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {stdError} from "forge-std/Test.sol";
import {TestHelper} from "../../../TestHelper.sol";

import {ERC1155Items} from "src/tokens/ERC1155/presets/items/ERC1155Items.sol";
import {
    IERC1155ItemsSignals,
    IERC1155ItemsFunctions,
    IERC1155Items
} from "src/tokens/ERC1155/presets/items/IERC1155Items.sol";
import {ERC1155ItemsFactory} from "src/tokens/ERC1155/presets/items/ERC1155ItemsFactory.sol";
import {IERC1155SupplyFunctions} from "src/tokens/ERC1155/extensions/supply/IERC1155Supply.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

// Interfaces
import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {IERC1155} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155.sol";
import {IERC1155Metadata} from "@0xsequence/erc-1155/contracts/tokens/ERC1155/ERC1155Metadata.sol";

contract ERC1155ItemsTest is TestHelper, IERC1155ItemsSignals {
    // Redeclare events
    event TransferSingle(
        address indexed _operator, address indexed _from, address indexed _to, uint256 _id, uint256 _amount
    );
    event TransferBatch(
        address indexed _operator, address indexed _from, address indexed _to, uint256[] _ids, uint256[] _amounts
    );

    ERC1155Items private token;

    address private proxyOwner;
    address private owner;

    function setUp() public {
        owner = makeAddr("owner");
        proxyOwner = makeAddr("proxyOwner");

        vm.deal(address(this), 100 ether);
        vm.deal(owner, 100 ether);

        ERC1155ItemsFactory factory = new ERC1155ItemsFactory(address(this));
        token = ERC1155Items(factory.deploy(proxyOwner, owner, "name", "baseURI", "contractURI", address(this), 0));
    }

    function testReinitializeFails() public {
        vm.expectRevert(InvalidInitialization.selector);
        token.initialize(owner, "name", "baseURI", "contractURI", address(this), 0);
    }

    function testSupportsInterface() public view {
        assertTrue(token.supportsInterface(type(IERC165).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155Metadata).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155SupplyFunctions).interfaceId));
        assertTrue(token.supportsInterface(type(IERC1155ItemsFunctions).interfaceId));
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
        checkSelectorCollision(0xe985e9c5); // isApprovedForAll(address,address)
        checkSelectorCollision(0x731133e9); // mint(address,uint256,uint256,bytes)
        checkSelectorCollision(0x06fdde03); // name()
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
        checkSelectorCollision(0x5944c753); // setTokenRoyalty(uint256,address,uint96)
        checkSelectorCollision(0x01ffc9a7); // supportsInterface(bytes4)
        checkSelectorCollision(0x2693ebf2); // tokenSupply(uint256)
        checkSelectorCollision(0x18160ddd); // totalSupply()
        checkSelectorCollision(0x0e89341c); // uri(uint256)
    }

    function testOwnerHasRoles() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), owner));
        assertTrue(token.hasRole(keccak256("METADATA_ADMIN_ROLE"), owner));
        assertTrue(token.hasRole(keccak256("MINTER_ROLE"), owner));
        assertTrue(token.hasRole(keccak256("ROYALTY_ADMIN_ROLE"), owner));
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
        ERC1155ItemsFactory factory = new ERC1155ItemsFactory(address(this));
        address deployedAddr =
            factory.deploy(_proxyOwner, tokenOwner, name, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator);
        address predictedAddr = factory.determineAddress(
            _proxyOwner, tokenOwner, name, baseURI, contractURI, royaltyReceiver, royaltyFeeNumerator
        );
        assertEq(deployedAddr, predictedAddr);
    }

    //
    // Metadata
    //
    function testContractURI() external {
        address nonOwner = makeAddr("nonOwner");
        vm.expectRevert(); // Missing role
        vm.prank(nonOwner);
        token.setContractURI("contract://");

        vm.prank(owner);
        token.setContractURI("contract://");
        assertEq("contract://", token.contractURI());
    }

    //
    // Minting
    //
    function testMintInvalidRole(address caller) public {
        vm.assume(caller != owner);
        vm.assume(caller != proxyOwner);

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(caller),
                " is missing role ",
                vm.toString(keccak256("MINTER_ROLE"))
            )
        );
        vm.prank(caller);
        token.mint(caller, 1, 1, "");

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(caller),
                " is missing role ",
                vm.toString(keccak256("MINTER_ROLE"))
            )
        );
        vm.prank(caller);
        token.batchMint(caller, tokenIds, amounts, "");
    }

    function testMintOwner(uint256 tokenId, uint256 amount) public {
        vm.assume(amount > 0);

        vm.expectEmit(true, true, true, true, address(token));
        emit TransferSingle(owner, address(0), owner, tokenId, amount);
        vm.prank(owner);
        token.mint(owner, tokenId, amount, "");

        assertEq(token.balanceOf(owner, tokenId), amount);
    }

    function testBatchMintOwner(uint256[] memory tokenIds, uint256[] memory amounts) public {
        tokenIds = boundArrayLength(tokenIds, 10);
        amounts = boundArrayLength(amounts, tokenIds.length);
        vm.assume(tokenIds.length == amounts.length);
        for (uint256 i; i < amounts.length; i++) {
            if (amounts[i] == 0) {
                amounts[i] = 1;
            } else if (amounts[i] > 1e6) {
                amounts[i] = 1e6;
            }
        }
        assumeNoDuplicates(tokenIds);

        vm.expectEmit(true, true, true, true, address(token));
        emit TransferBatch(owner, address(0), owner, tokenIds, amounts);
        vm.prank(owner);
        token.batchMint(owner, tokenIds, amounts, "");
    }

    function testMintWithRole(address minter, uint256 tokenId, uint256 amount) public {
        vm.assume(minter != owner);
        vm.assume(minter != proxyOwner);
        vm.assume(minter != address(0));
        // Give role
        vm.startPrank(owner);
        token.grantRole(keccak256("MINTER_ROLE"), minter);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true, address(token));
        emit TransferSingle(minter, address(0), owner, tokenId, amount);

        vm.prank(minter);
        token.mint(owner, tokenId, amount, "");

        assertEq(token.balanceOf(owner, tokenId), amount);
    }

    function testBatchMintWithRole(address minter, uint256[] memory tokenIds, uint256[] memory amounts) public {
        vm.assume(minter != owner);
        vm.assume(minter != proxyOwner);
        vm.assume(minter != address(0));
        tokenIds = boundArrayLength(tokenIds, 10);
        amounts = boundArrayLength(amounts, tokenIds.length);
        vm.assume(tokenIds.length == amounts.length);
        for (uint256 i; i < amounts.length; i++) {
            if (amounts[i] == 0) {
                amounts[i] = 1;
            } else if (amounts[i] > 1e6) {
                amounts[i] = 1e6;
            }
        }
        assumeNoDuplicates(tokenIds);

        // Give role
        vm.startPrank(owner);
        token.grantRole(keccak256("MINTER_ROLE"), minter);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true, address(token));
        emit TransferBatch(minter, address(0), owner, tokenIds, amounts);
        vm.prank(minter);
        token.batchMint(owner, tokenIds, amounts, "");
    }

    //
    // Burn
    //
    function testBurnSuccess(address caller, uint256 tokenId, uint256 amount, uint256 burnAmount) public {
        assumeSafeAddress(caller);
        vm.assume(caller != owner);
        vm.assume(caller != proxyOwner);
        vm.assume(amount >= burnAmount);
        vm.assume(amount > 0);

        vm.prank(owner);
        token.mint(caller, tokenId, amount, "");

        vm.expectEmit(true, true, true, false, address(token));
        emit TransferSingle(caller, caller, address(0), tokenId, amount);

        vm.prank(caller);
        token.burn(tokenId, burnAmount);

        assertEq(token.balanceOf(caller, tokenId), amount - burnAmount);
        assertEq(token.tokenSupply(tokenId), amount - burnAmount);
        assertEq(token.totalSupply(), amount - burnAmount);
    }

    function testBurnInvalidOwnership(address caller, uint256 tokenId, uint256 amount, uint256 burnAmount) public {
        assumeSafeAddress(caller);
        vm.assume(caller != owner);
        vm.assume(caller != proxyOwner);
        vm.assume(burnAmount > amount);

        vm.prank(owner);
        token.mint(caller, tokenId, amount, "");

        vm.expectRevert(stdError.arithmeticError);
        token.burn(tokenId, burnAmount);
    }

    function testBurnBatchSuccess(
        address caller,
        uint256[] memory tokenIds,
        uint256[] memory amounts,
        uint256[] memory burnAmounts
    ) public {
        assumeSafeAddress(caller);
        vm.assume(caller != owner);
        vm.assume(caller != proxyOwner);

        uint256 nTokenIds = tokenIds.length > 3 ? 3 : tokenIds.length;
        vm.assume(nTokenIds > 0);
        vm.assume(nTokenIds <= amounts.length);
        vm.assume(nTokenIds <= burnAmounts.length);
        // Bind array sizes
        assembly {
            mstore(tokenIds, nTokenIds)
            mstore(amounts, nTokenIds)
            mstore(burnAmounts, nTokenIds)
        }

        for (uint256 i; i < nTokenIds; i++) {
            // Lower the values
            tokenIds[i] = tokenIds[i] % 256;
            amounts[i] = amounts[i] % 256;

            // Ensure we don't burn too many
            if (burnAmounts[i] > amounts[i]) {
                burnAmounts[i] = amounts[i];
            }
        }
        assumeNoDuplicates(tokenIds);

        vm.prank(owner);
        token.batchMint(caller, tokenIds, amounts, "");

        vm.expectEmit(true, true, true, false, address(token));
        emit TransferBatch(caller, caller, address(0), tokenIds, burnAmounts);

        vm.prank(caller);
        token.batchBurn(tokenIds, burnAmounts);

        uint256 totalAmount;
        uint256 totalBurnAmount;
        for (uint256 i; i < nTokenIds; i++) {
            assertEq(token.balanceOf(caller, tokenIds[i]), amounts[i] - burnAmounts[i]);
            assertEq(token.tokenSupply(tokenIds[i]), amounts[i] - burnAmounts[i]);
            totalAmount += amounts[i];
            totalBurnAmount += burnAmounts[i];
        }
        assertEq(token.totalSupply(), totalAmount - totalBurnAmount);
    }

    function testBurnBatchInvalidOwnership(address caller, uint256[] memory tokenIds, uint256[] memory amounts)
        public
    {
        assumeSafeAddress(caller);
        vm.assume(caller != owner);
        vm.assume(caller != proxyOwner);

        uint256 nTokenIds = tokenIds.length > 3 ? 3 : tokenIds.length;
        vm.assume(nTokenIds > 0);
        vm.assume(nTokenIds <= amounts.length);
        // Bind array sizes
        assembly {
            mstore(tokenIds, nTokenIds)
            mstore(amounts, nTokenIds)
        }

        for (uint256 i; i < nTokenIds; i++) {
            // Lower the values
            tokenIds[i] = tokenIds[i] % 256;
            amounts[i] = amounts[i] % 256;
        }
        assumeNoDuplicates(tokenIds);

        vm.prank(owner);
        token.batchMint(caller, tokenIds, amounts, "");

        amounts[0]++; // Now we burn too many

        vm.expectRevert(stdError.arithmeticError);
        token.batchBurn(tokenIds, amounts);
    }

    //
    // Metadata
    //
    function testMetadataOwner() public {
        vm.prank(owner);
        token.setBaseMetadataURI("ipfs://newURI/");

        assertEq(token.uri(0), "ipfs://newURI/0.json");
        assertEq(token.uri(1), "ipfs://newURI/1.json");
    }

    function testMetadataInvalid(address caller) public {
        vm.assume(caller != owner);
        vm.assume(caller != proxyOwner);
        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(caller),
                " is missing role ",
                vm.toString(keccak256("METADATA_ADMIN_ROLE"))
            )
        );
        vm.prank(caller);
        token.setBaseMetadataURI("ipfs://newURI/");
    }

    function testMetadataWithRole(address caller) public {
        vm.assume(caller != owner);
        vm.assume(caller != proxyOwner);
        vm.assume(caller != address(0));
        // Give role
        vm.startPrank(owner);
        token.grantRole(keccak256("METADATA_ADMIN_ROLE"), caller);
        vm.stopPrank();

        vm.prank(caller);
        token.setBaseMetadataURI("ipfs://newURI/");
    }

    //
    // Royalty
    //
    function testDefaultRoyalty(address receiver, uint96 feeNumerator, uint256 salePrice) public {
        vm.assume(feeNumerator <= 10000);
        vm.assume(receiver != address(0));
        vm.assume(salePrice < type(uint128).max); // Buffer for overflow

        vm.prank(owner);
        token.setDefaultRoyalty(receiver, feeNumerator);

        (address receiver_, uint256 amount) = token.royaltyInfo(1, salePrice);
        assertEq(receiver_, receiver);
        assertEq(amount, salePrice * feeNumerator / 10000);
    }

    function testTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator, uint256 salePrice) public {
        vm.assume(feeNumerator <= 10000);
        vm.assume(receiver != address(0));
        vm.assume(tokenId != 69); // Other token id for default validation
        vm.assume(salePrice < type(uint128).max); // Buffer for overflow

        vm.prank(owner);
        token.setTokenRoyalty(tokenId, receiver, feeNumerator);

        (address receiver_, uint256 amount) = token.royaltyInfo(tokenId, salePrice);
        assertEq(receiver_, receiver);
        assertEq(amount, salePrice * feeNumerator / 10000);

        (receiver_, amount) = token.royaltyInfo(69, salePrice);
        assertEq(receiver_, address(this));
        assertEq(amount, 0);
    }

    function testRoyaltyWithRole(
        address caller,
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator,
        uint256 salePrice
    ) public {
        vm.assume(feeNumerator <= 10000);
        vm.assume(receiver != address(0));
        vm.assume(caller != owner);
        vm.assume(caller != proxyOwner);
        vm.assume(salePrice < type(uint128).max); // Buffer for overflow

        vm.startPrank(owner);
        token.grantRole(keccak256("ROYALTY_ADMIN_ROLE"), caller);
        vm.stopPrank();

        vm.prank(caller);
        token.setDefaultRoyalty(receiver, feeNumerator);

        (address receiver_, uint256 amount) = token.royaltyInfo(1, salePrice);
        assertEq(receiver_, receiver);
        assertEq(amount, salePrice * feeNumerator / 10000);

        vm.prank(caller);
        token.setTokenRoyalty(tokenId, receiver, feeNumerator);

        (receiver_, amount) = token.royaltyInfo(tokenId, salePrice);
        assertEq(receiver_, receiver);
        assertEq(amount, salePrice * feeNumerator / 10000);
    }

    function testRoyaltyInvalidRole(
        address caller,
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator,
        uint256 salePrice
    ) public {
        vm.assume(feeNumerator <= 10000);
        vm.assume(receiver != address(0));
        vm.assume(caller != owner);
        vm.assume(caller != proxyOwner);
        vm.assume(salePrice < type(uint128).max); // Buffer for overflow

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(caller),
                " is missing role ",
                vm.toString(keccak256("ROYALTY_ADMIN_ROLE"))
            )
        );
        vm.prank(caller);
        token.setDefaultRoyalty(receiver, feeNumerator);

        vm.expectRevert(
            abi.encodePacked(
                "AccessControl: account ",
                Strings.toHexString(caller),
                " is missing role ",
                vm.toString(keccak256("ROYALTY_ADMIN_ROLE"))
            )
        );
        vm.prank(caller);
        token.setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    function boundArrayLength(uint256[] memory arr, uint256 maxSize) private pure returns (uint256[] memory) {
        if (arr.length <= maxSize) {
            return arr;
        }
        // solhint-disable-next-line no-inline-assembly
        assembly {
            mstore(arr, maxSize)
        }
        return arr;
    }
}
