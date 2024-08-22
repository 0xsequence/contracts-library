// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

import {PaymentSplitter, IERC20Upgradeable} from "@0xsequence/contracts-library/payments/PaymentSplitter.sol";
import {
    IPaymentCombiner, IPaymentCombinerFunctions
} from "@0xsequence/contracts-library/payments/IPaymentCombiner.sol";
import {IERC165} from "@0xsequence/erc-1155/contracts/interfaces/IERC165.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

/**
 * Deployer of Payment Splitter proxies.
 * @dev Unlike other factories in this library, payment splitters are unowned and not upgradeable.
 */
contract PaymentCombiner is IPaymentCombiner, IERC165 {
    using Clones for address;

    address private immutable _IMPLEMENTATION;

    mapping(address => address[]) private _payeeSplitters;

    /**
     * Creates a Payment Splitter Factory.
     */
    constructor() {
        _IMPLEMENTATION = address(new PaymentSplitter());
    }

    /// @inheritdoc IPaymentCombinerFunctions
    function implementationAddress() external view returns (address) {
        return _IMPLEMENTATION;
    }

    /// @inheritdoc IPaymentCombinerFunctions
    function deploy(address[] calldata payees, uint256[] calldata shares) external returns (address proxyAddr) {
        bytes32 salt = _determineSalt(payees, shares);
        proxyAddr = _IMPLEMENTATION.cloneDeterministic(salt);
        PaymentSplitter(payable(proxyAddr)).initialize(payees, shares);
        emit PaymentSplitterDeployed(proxyAddr);

        // Add the payees to the list of payee splitters
        for (uint256 i = 0; i < payees.length; i++) {
            _payeeSplitters[payees[i]].push(proxyAddr);
        }

        return proxyAddr;
    }

    /// @inheritdoc IPaymentCombinerFunctions
    function determineAddress(address[] calldata payees, uint256[] calldata shares)
        external
        view
        returns (address proxyAddr)
    {
        bytes32 salt = _determineSalt(payees, shares);
        return _IMPLEMENTATION.predictDeterministicAddress(salt);
    }

    /// @dev Computes the deployment salt for a Payment Splitter.
    function _determineSalt(address[] calldata payees, uint256[] calldata shares) internal pure returns (bytes32) {
        return keccak256(abi.encode(payees, shares));
    }

    /// @inheritdoc IPaymentCombinerFunctions
    function listPayeeSplitters(address payee) external view returns (address[] memory splitterAddrs) {
        return _payeeSplitters[payee];
    }

    /// @inheritdoc IPaymentCombinerFunctions
    function listReleasable(address payee, address tokenAddr, address[] calldata splitterAddrs)
        external
        view
        returns (uint256[] memory pendingShares)
    {
        uint256 len = splitterAddrs.length;
        uint256[] memory payeePendingShares = new uint256[](len);

        if (tokenAddr == address(0)) {
            for (uint256 i = 0; i < len;) {
                payeePendingShares[i] = PaymentSplitter(payable(splitterAddrs[i])).releasable(payee);
                unchecked {
                    i++;
                }
            }
        } else {
            IERC20Upgradeable token = IERC20Upgradeable(tokenAddr);
            for (uint256 i = 0; i < len;) {
                payeePendingShares[i] = PaymentSplitter(payable(splitterAddrs[i])).releasable(token, payee);
                unchecked {
                    i++;
                }
            }
        }

        return payeePendingShares;
    }

    /// @inheritdoc IPaymentCombinerFunctions
    function release(address payable payee, address tokenAddr, address[] calldata splitterAddrs) external {
        uint256 len = splitterAddrs.length;
        if (tokenAddr == address(0)) {
            for (uint256 i = 0; i < len;) {
                PaymentSplitter(payable(splitterAddrs[i])).release(payee);
                unchecked {
                    i++;
                }
            }
        } else {
            IERC20Upgradeable token = IERC20Upgradeable(tokenAddr);
            for (uint256 i = 0; i < len;) {
                PaymentSplitter(payable(splitterAddrs[i])).release(token, payee);
                unchecked {
                    i++;
                }
            }
        }
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return type(IPaymentCombiner).interfaceId == interfaceId
            || type(IPaymentCombinerFunctions).interfaceId == interfaceId || type(IERC165).interfaceId == interfaceId;
    }
}
