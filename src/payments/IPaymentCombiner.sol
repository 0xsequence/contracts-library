// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IPaymentCombinerFunctions {
    /**
     * Get the address of the PaymentSplitter implementation.
     * @return implementationAddr The address of the PaymentSplitter implementation.
     */
    function implementationAddress() external view returns (address implementationAddr);

    /**
     * Creates a PaymentSplitter proxy.
     * @param payees The addresses of the payees
     * @param shares The number of shares each payee has
     * @return proxyAddr The address of the deployed proxy
     */
    function deploy(address[] calldata payees, uint256[] calldata shares) external returns (address proxyAddr);

    /**
     * Computes the address of a proxy instance.
     * @param payees The addresses of the payees
     * @param shares The number of shares each payee has
     * @return proxyAddr The address of the proxy
     */
    function determineAddress(address[] calldata payees, uint256[] calldata shares)
        external
        returns (address proxyAddr);

    /**
     * Get the list of Payment Splitters this payee is associated with.
     * @param payee The address of the payee
     * @return splitterAddrs The list of payments splitters
     */
    function listPayeeSplitters(address payee) external view returns (address[] memory splitterAddrs);

    /**
     * Get the list of pending shares for a payee.
     * @param payee The address of the payee
     * @param tokenAddr The address of the ERC-20 token. If the token address is 0x0, then the native token is used.
     * @param splitterAddrs The list of payments splitters to check. If empty then all splitters are used.
     * @return pendingShares The list of pending shares
     * @dev The list includes zero balances. These should be removed before releasing shares.
     */
    function listReleasable(address payee, address tokenAddr, address[] memory splitterAddrs)
        external
        view
        returns (uint256[] memory pendingShares);

    /**
     * Release the pending shares for a payee.
     * @param payee The address of the payee
     * @param tokenAddr The address of the ERC-20 token. If the token address is 0x0, then the native token is used.
     * @param splitterAddrs The list of payments splitters to release shares from. If empty then all splitters are used.
     * @dev Use the above functions to get the list of splitters and pending shares.
     * @dev Calling splitters with no shares to release will fail.
     */
    function release(address payable payee, address tokenAddr, address[] calldata splitterAddrs) external;
}

interface IPaymentCombinerSignals {
    /**
     * Event emitted when a new proxy contract is deployed.
     * @param proxyAddr The address of the deployed proxy.
     */
    event PaymentSplitterDeployed(address proxyAddr);
}

interface IPaymentCombiner is IPaymentCombinerFunctions, IPaymentCombinerSignals {}
