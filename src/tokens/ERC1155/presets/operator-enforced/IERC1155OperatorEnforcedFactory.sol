// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.19;

interface IERC1155OperatorEnforcedFactoryFunctions {
    /**
     * Creates an ERC-1155 Operator Enforced proxy.
     * @param proxyOwner The owner of the ERC-1155 Operator Enforced proxy
     * @param tokenOwner The owner of the ERC-1155 Operator Enforced implementation
     * @param tokenName Token name
     * @param tokenBaseURI Base URI for token metadata
     * @param tokenContractURI Contract URI for token metadata
     * @param royaltyReceiver Address of who should be sent the royalty payment
     * @param royaltyFeeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @param operatorAllowlist Address of the operator allowlist
     * @return proxyAddr The address of the ERC-1155 Operator Enforced Proxy
     */
    function deploy(
        address proxyOwner,
        address tokenOwner,
        string memory tokenName,
        string memory tokenBaseURI,
        string memory tokenContractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        address operatorAllowlist
    ) external returns (address proxyAddr);

    /**
     * Computes the address of a proxy instance.
     * @param proxyOwner The owner of the ERC-1155 Operator Enforced proxy
     * @param tokenOwner The owner of the ERC-1155 Operator Enforced implementation
     * @param tokenName Token name
     * @param tokenBaseURI Base URI for token metadata
     * @param tokenContractURI Contract URI for token metadata
     * @param royaltyReceiver Address of who should be sent the royalty payment
     * @param royaltyFeeNumerator The royalty fee numerator in basis points (e.g. 15% would be 1500)
     * @param operatorAllowlist Address of the operator allowlist
     * @return proxyAddr The address of the ERC-1155 Operator Enforced Proxy
     */
    function determineAddress(
        address proxyOwner,
        address tokenOwner,
        string memory tokenName,
        string memory tokenBaseURI,
        string memory tokenContractURI,
        address royaltyReceiver,
        uint96 royaltyFeeNumerator,
        address operatorAllowlist
    ) external returns (address proxyAddr);
}

interface IERC1155OperatorEnforcedFactorySignals {
    /**
     * Event emitted when a new ERC-1155 Operator Enforced proxy contract is deployed.
     * @param proxyAddr The address of the deployed proxy.
     */
    event ERC1155OperatorEnforcedDeployed(address proxyAddr);
}

interface IERC1155OperatorEnforcedFactory is
    IERC1155OperatorEnforcedFactoryFunctions,
    IERC1155OperatorEnforcedFactorySignals
{}
