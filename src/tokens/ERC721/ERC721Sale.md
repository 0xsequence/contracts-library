# ERC721 Sale

ERC721 Sale is a Solidity contract designed to allow controlled sale and minting of ERC-721 non-fungible tokens (NFTs).

The contract utilizes the ERC-721 token standard, allowing for the creation of multiple token within a single contract. 

## Overview

This contract offers a way to mint and sell ERC-721 tokens under specific conditions. It provides admin functionality for minting, sets conditions for claimable tokens, checks for claim conditions before allowing a claim, and ensures no claim exceeds the maximum claimable supply.

## Features

- **Admin Minting**: Administrators can mint tokens directly to a receiver's address.
- **Claim Conditions**: Claim conditions can be set to control the sale of the ERC-721 tokens.
- **Token Claiming**: Tokens can be claimed by an actor as long as the specified conditions are met.

## Contract Methods

- `adminClaim(receiver, amount)`: Allows an admin to mint a specific amount of tokens to a receiver's address.
- `setClaimConditions(conditions, status)`: Sets claim conditions for tokens. Conditions can be an array of ClaimCondition structs, and status a boolean indicating the condition status.
- `claim(receiver, amount, address, value, proof, data)`: Claims a certain amount of tokens for a receiver if the conditions are met. Any claim that does not meet the conditions is reverted.

## Claiming and Claim Conditions

One of the primary features of the ERC721 Sale contract is the ability to set conditions for claiming tokens, and to perform those claims. This ensures a fair distribution of the tokens according to the predetermined rules.

### Claiming Tokens

The claim operation is a way for an actor (a user or another smart contract) to request a specific amount of ERC721 tokens. This is done through the `claim` function:

```solidity
claim(receiver, amount, address, value, proof, data)
```

The parameters of the claim function are as follows:

- `receiver`: The address of the entity receiving the tokens.
- `amount`: The number of tokens to be claimed.
- `address`: Additional address parameter, its usage can be customized based on your contract implementation.
- `value`: Additional value parameter, its usage can be customized based on your contract implementation.
- `proof`: Contains the proof information for the claim. This data is typically used when the token has been put on an allowlist.
- `data`: Additional data field, its usage can be customized based on your contract implementation.

### Claim Conditions

Before a token can be claimed, the contract checks if the claim conditions for the token are met. These conditions are set via the `setClaimConditions` function:

```solidity
setClaimConditions(conditions, status)
```

The parameters of this function are:

- `conditions`: An array of `ClaimCondition` structs. Each struct can have a `startTimestamp` (the minimum time when the token can be claimed), `maxClaimableSupply` (the total number of this token that can be claimed), and `quantityLimitPerWallet` (the maximum quantity of this token that a single wallet can claim).
- `status`: A boolean indicating the condition status. This could be used to activate or deactivate the conditions.

The conditions are checked each time a claim is made. If the conditions are not met, the transaction is reverted. Some of the checks include:

- Checking that the current time is not before the `startTimestamp`.
- Checking that the total supply of claimed tokens does not exceed `maxClaimableSupply`.
- Checking that the quantity being claimed does not exceed the `quantityLimitPerWallet`.

This system allows the contract administrator to control the distribution of the tokens in a fair and predictable manner. It also allows for the implementation of exclusive access periods, capped supply models, and more.
