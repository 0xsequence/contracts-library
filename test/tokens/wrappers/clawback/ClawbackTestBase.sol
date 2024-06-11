// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {Test, console, stdError} from "forge-std/Test.sol";
import {IERC721TokenReceiver} from "forge-std/interfaces/IERC721.sol";

import {Clawback} from "src/tokens/wrappers/clawback/Clawback.sol";
import {ClawbackMetadata} from "src/tokens/wrappers/clawback/ClawbackMetadata.sol";
import {IClawbackFunctions} from "src/tokens/wrappers/clawback/IClawback.sol";

import {ERC1155Mock} from "test/_mocks/ERC1155Mock.sol";
import {ERC20Mock} from "test/_mocks/ERC20Mock.sol";
import {ERC721Mock} from "test/_mocks/ERC721Mock.sol";
import {IGenericToken} from "test/_mocks/IGenericToken.sol";

import {IERC1155TokenReceiver} from "@0xsequence/erc-1155/contracts/interfaces/IERC1155TokenReceiver.sol";

contract ClawbackTestBase is Test, IERC1155TokenReceiver, IERC721TokenReceiver {
    Clawback public clawback;
    ClawbackMetadata public clawbackMetadata;
    ERC20Mock public erc20;
    ERC721Mock public erc721;
    ERC1155Mock public erc1155;

    function setUp() public {
        clawbackMetadata = new ClawbackMetadata();
        clawback = new Clawback(address(this), address(clawbackMetadata));
        erc20 = new ERC20Mock(address(this));
        erc721 = new ERC721Mock(address(this), "baseURI");
        erc1155 = new ERC1155Mock(address(this), "baseURI");
    }

    function _toTokenType(uint8 tokenType) internal pure returns (IClawbackFunctions.TokenType) {
        tokenType = tokenType % 3;
        if (tokenType == 0) {
            return IClawbackFunctions.TokenType.ERC20;
        }
        if (tokenType == 1) {
            return IClawbackFunctions.TokenType.ERC721;
        }
        return IClawbackFunctions.TokenType.ERC1155;
    }

    function _validParams(IClawbackFunctions.TokenType tokenType, uint256 tokenId, uint256 amount)
        internal
        view
        returns (address, uint256, uint256)
    {
        if (tokenType == IClawbackFunctions.TokenType.ERC20) {
            return (address(erc20), 0, bound(amount, 1, type(uint256).max));
        }
        if (tokenType == IClawbackFunctions.TokenType.ERC721) {
            return (address(erc721), bound(tokenId, 1, type(uint256).max), 1);
        }
        return (address(erc1155), tokenId, bound(amount, 1, type(uint128).max));
    }

    struct WrapSetupResult {
        uint256 tokenId;
        uint256 amount;
        uint56 duration;
        address tokenAddr;
        uint32 templateId;
        uint256 wrappedTokenId;
    }

    function _wrapSetup(
        address templateAdmin,
        uint8 tokenTypeNum,
        uint256 tokenId,
        uint256 amount,
        uint56 duration,
        address receiver
    ) internal returns (WrapSetupResult memory result) {
        vm.assume(templateAdmin != address(0));

        // Unwrap timestamp is uint64 as per ERC721A implmentation used by ERC721Mock
        result.duration = uint56(bound(duration, 1, type(uint64).max - block.timestamp));

        vm.prank(templateAdmin);
        result.templateId = clawback.addTemplate(result.duration, false, false);

        IClawbackFunctions.TokenType tokenType = _toTokenType(tokenTypeNum);
        (result.tokenAddr, result.tokenId, result.amount) = _validParams(tokenType, tokenId, amount);

        IGenericToken(result.tokenAddr).mint(address(this), result.tokenId, result.amount);
        IGenericToken(result.tokenAddr).approve(address(this), address(clawback), result.tokenId, result.amount);

        result.wrappedTokenId =
            clawback.wrap(result.templateId, tokenType, result.tokenAddr, result.tokenId, result.amount, receiver);

        // struct here prevents stack too deep during coverage reporting
        return result;
    }

    // Receiver

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    // Helper

    modifier safeAddress(address addr) {
        vm.assume(addr != address(0));
        vm.assume(addr.code.length <= 2);
        assumeNotPrecompile(addr);
        assumeNotForgeAddress(addr);
        _;
    }
}
