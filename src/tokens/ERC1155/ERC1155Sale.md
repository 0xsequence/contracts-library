# ERC1155 Sale

ERC1155 Sale is a Solidity contract designed to allow controlled sale and minting of ERC-1155 semi-fungible tokens (SFTs).

The contract utilizes the ERC-1155 token standard, allowing for the creation of multiple token types within a single contract. ERC-1155 tokens are especially useful in scenarios where multiple classes of assets need to be issued by a single contract.

## Overview

This contract offers a way to mint and sell ERC-1155 tokens under specific conditions. It provides admin functionality for minting, sets conditions for claimable tokens, checks for claim conditions before allowing a claim, and ensures no claim exceeds the maximum claimable supply.

## Features

- **Admin Minting**: Administrators can mint tokens directly to a receiver's address.
- **Claim Conditions**: Claim conditions can be set to control the sale of the ERC-1155 tokens.
- **Token Claiming**: Tokens can be claimed by an actor as long as the specified conditions are met.

## Contract Methods

- `adminClaim(receiver, tokenId, amount)`: Allows an admin to mint a specific amount of a token to a receiver's address.
- `setClaimConditions(tokenId, conditions, status)`: Sets claim conditions for a token. Conditions can be an array of ClaimCondition structs, and status a boolean indicating the condition status.
- `claim(receiver, tokenId, amount, address, value, proof, data)`: Claims a certain amount of a token for a receiver if the conditions are met. Any claim that does not meet the conditions is reverted.

## Claiming and Claim Conditions

One of the primary features of the ERC1155 Sale contract is the ability to set conditions for claiming tokens, and to perform those claims. This ensures a fair distribution of the tokens according to the predetermined rules.

### Claiming Tokens

The claim operation is a way for an actor (a user or another smart contract) to request a specific amount of a certain ERC1155 token. This is done through the `claim` function:

```solidity
claim(receiver, tokenId, amount, address, value, proof, data)
```

The parameters of the claim function are as follows:

- `receiver`: The address of the entity receiving the tokens.
- `tokenId`: The identifier of the specific token type being claimed.
- `amount`: The number of tokens to be claimed.
- `address`: Additional address parameter, its usage can be customized based on your contract implementation.
- `value`: Additional value parameter, its usage can be customized based on your contract implementation.
- `proof`: Contains the proof information for the claim. This data is typically used when the token has been put on an allowlist.
- `data`: Additional data field, its usage can be customized based on your contract implementation.

### Claim Conditions

Before a token can be claimed, the contract checks if the claim conditions for the token are met. These conditions are set via the `setClaimConditions` function:

```solidity
setClaimConditions(tokenId, conditions, status)
```

The parameters of this function are:

- `tokenId`: The identifier of the specific token type for which the conditions are being set.
- `conditions`: An array of `ClaimCondition` structs. Each struct can have a `startTimestamp` (the minimum time when the token can be claimed), `maxClaimableSupply` (the total number of this token that can be claimed), and `quantityLimitPerWallet` (the maximum quantity of this token that a single wallet can claim).
- `status`: A boolean indicating the condition status. This could be used to activate or deactivate the conditions.

The conditions are checked each time a claim is made. If the conditions are not met, the transaction is reverted. Some of the checks include:

- Checking that the current time is not before the `startTimestamp`.
- Checking that the total supply of claimed tokens does not exceed `maxClaimableSupply`.
- Checking that the quantity being claimed does not exceed the `quantityLimitPerWallet`.

This system allows the contract administrator to control the distribution of the tokens in a fair and predictable manner. It also allows for the implementation of exclusive access periods, capped supply models, and more.
