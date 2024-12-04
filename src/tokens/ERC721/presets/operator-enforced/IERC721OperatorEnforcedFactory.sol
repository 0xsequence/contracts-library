// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IERC721OperatorEnforcedFactoryFunctions {
    /**
     * Creates an ERC-721 Operator Enforced proxy.
     * @param proxyOwner The owner of the ERC-721 Operator Enforced proxy
     * @param tokenOwner The owner of the ERC-721 Operator Enforced implementation
     * @param name The name of the ERC-721 Operator Enforced proxy
     * @param symbol The symbol of the ERC-721 Operator Enforced proxy
     * @param baseURI The base URI of the ERC-721 Operator Enforced proxy
     * @param contractURI The contract URI of the ERC-721 Operator Enforced proxy
     * @param royaltyReceiver Address of who should be sent the royalty payment
     * @param royaltyFeeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @param operatorAllowlist Address of the operator allowlist
     * @return proxyAddr The address of the ERC-721 Operator Enforced Proxy
     */
    function deploy(
        address proxyOwner,
        address tokenOwner,
        string memory name,
        string memory symbol,
        string memory baseURI,
        string memory contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        address operatorAllowlist
    ) external returns (address proxyAddr);

    /**
     * Computes the address of a proxy instance.
     * @param proxyOwner The owner of the ERC-721 Operator Enforced proxy
     * @param tokenOwner The owner of the ERC-721 Operator Enforced implementation
     * @param name The name of the ERC-721 Operator Enforced proxy
     * @param symbol The symbol of the ERC-721 Operator Enforced proxy
     * @param baseURI The base URI of the ERC-721 Operator Enforced proxy
     * @param contractURI The contract URI of the ERC-721 Operator Enforced proxy
     * @param royaltyReceiver Address of who should be sent the royalty payment
     * @param royaltyFeeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @param operatorAllowlist Address of the operator allowlist
     * @return proxyAddr The address of the ERC-721 Operator Enforced Proxy
     */
    function determineAddress(
        address proxyOwner,
        address tokenOwner,
        string memory name,
        string memory symbol,
        string memory baseURI,
        string memory contractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        address operatorAllowlist
    ) external returns (address proxyAddr);
}

interface IERC721OperatorEnforcedFactorySignals {
    /**
     * Event emitted when a new ERC-721 Operator Enforced proxy contract is deployed.
     * @param proxyAddr The address of the deployed proxy.
     */
    event ERC721OperatorEnforcedDeployed(address proxyAddr);
}

interface IERC721OperatorEnforcedFactory is
    IERC721OperatorEnforcedFactoryFunctions,
    IERC721OperatorEnforcedFactorySignals
{}
