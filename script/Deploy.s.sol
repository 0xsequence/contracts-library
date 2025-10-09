// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { PaymentCombiner } from "../src/payments/PaymentCombiner.sol";
import { PaymentsFactory } from "../src/payments/PaymentsFactory.sol";

import { ERC1155ItemsFactory } from "../src/tokens/ERC1155/presets/items/ERC1155ItemsFactory.sol";
import { ERC1155PackFactory } from "../src/tokens/ERC1155/presets/pack/ERC1155PackFactory.sol";
import { ERC1155SoulboundFactory } from "../src/tokens/ERC1155/presets/soulbound/ERC1155SoulboundFactory.sol";
import { ERC1155Holder } from "../src/tokens/ERC1155/utility/holder/ERC1155Holder.sol";
import { ERC1155SaleFactory } from "../src/tokens/ERC1155/utility/sale/ERC1155SaleFactory.sol";

import { ERC20ItemsFactory } from "../src/tokens/ERC20/presets/items/ERC20ItemsFactory.sol";

import { ERC721ItemsFactory } from "../src/tokens/ERC721/presets/items/ERC721ItemsFactory.sol";
import { ERC721SoulboundFactory } from "../src/tokens/ERC721/presets/soulbound/ERC721SoulboundFactory.sol";
import { ERC721SaleFactory } from "../src/tokens/ERC721/utility/sale/ERC721SaleFactory.sol";

import { Clawback } from "../src/tokens/wrappers/clawback/Clawback.sol";
import { ClawbackMetadata } from "../src/tokens/wrappers/clawback/ClawbackMetadata.sol";

import { SingletonDeployer, console } from "erc2470-libs/script/SingletonDeployer.s.sol";

contract Deploy is SingletonDeployer {

    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address factoryOwner = vm.envAddress("FACTORY_OWNER");
        bytes32 salt = bytes32(0);

        _deployIfNotAlready(
            "ERC20ItemsFactory",
            abi.encodePacked(type(ERC20ItemsFactory).creationCode, abi.encode(factoryOwner)),
            salt,
            pk
        );
        _deployIfNotAlready(
            "ERC721ItemsFactory",
            abi.encodePacked(type(ERC721ItemsFactory).creationCode, abi.encode(factoryOwner)),
            salt,
            pk
        );
        _deployIfNotAlready(
            "ERC721SaleFactory",
            abi.encodePacked(type(ERC721SaleFactory).creationCode, abi.encode(factoryOwner)),
            salt,
            pk
        );
        _deployIfNotAlready(
            "ERC721SoulboundFactory",
            abi.encodePacked(type(ERC721SoulboundFactory).creationCode, abi.encode(factoryOwner)),
            salt,
            pk
        );
        _deployIfNotAlready(
            "ERC1155ItemsFactory",
            abi.encodePacked(type(ERC1155ItemsFactory).creationCode, abi.encode(factoryOwner)),
            salt,
            pk
        );
        _deployIfNotAlready(
            "ERC1155SaleFactory",
            abi.encodePacked(type(ERC1155SaleFactory).creationCode, abi.encode(factoryOwner)),
            salt,
            pk
        );
        _deployIfNotAlready(
            "ERC1155SoulboundFactory",
            abi.encodePacked(type(ERC1155SoulboundFactory).creationCode, abi.encode(factoryOwner)),
            salt,
            pk
        );
        address holder =
            _deployIfNotAlready("ERC1155Holder", abi.encodePacked(type(ERC1155Holder).creationCode), salt, pk);
        _deployIfNotAlready(
            "ERC1155PackFactory",
            abi.encodePacked(type(ERC1155PackFactory).creationCode, abi.encode(factoryOwner, holder)),
            salt,
            pk
        );
        _deployIfNotAlready(
            "PaymentsFactory", abi.encodePacked(type(PaymentsFactory).creationCode, abi.encode(factoryOwner)), salt, pk
        );
        _deployIfNotAlready("PaymentCombiner", abi.encodePacked(type(PaymentCombiner).creationCode), salt, pk);
        address clawbackMetadata =
            _deployIfNotAlready("ClawbackMetadata", abi.encodePacked(type(ClawbackMetadata).creationCode), salt, pk);
        _deployIfNotAlready(
            "Clawback",
            abi.encodePacked(
                type(Clawback).creationCode, abi.encode(factoryOwner, clawbackMetadata, address(0), bytes32(0))
            ),
            salt,
            pk
        );
    }

}
