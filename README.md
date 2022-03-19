# DaoSplit

A daosplit is a smart contract that allows locking of a single token type (Target Token) to be permissionlessly, proportionally rewarded from a pool of rewards (Rewards Pool), when a minimum number of `TargetToken` are supplied before an expiry time.

## Initializing a daosplit

A factory contract is provided on the following networks allowing parameterized creation of `DaoSplit` contract instances:

// table

Initializing a split requires parameters:

- `TargetToken`: address of the ERC20 that can be locked.
- `MinContributions`: minimum number of `TargetToken` that need to be locked in the contract to achieve completion.
- `Expiry`: timestamp of deadline when `MinContributions` of `TargetToken` must be supplied into the contract. Split state goes from `Active` to `Completed` or `Refund` at this time (see Split State).

## Split State

A daosplit can be in one of three states:

- *Active*: rewards can be contributed, and target tokens can be locked.
- *Complete*: completion condition has been met. Rewards are redeemable.
- *Refund*: `MinContribution` wasn't met before `Expiry` time was reached. Contributions are unlocked and can be reclaimed.

## Contributing

When a split is `Active`:

### Target Tokens
Addresses can contribute `TargetToken` to be entitled to a share of the final reward pool proportional to their share of the contributed `TargetToken`.

### Rewards
Addresses can contribute any ERC20 to the rewards pool.

## Refunds

When a split is `Refund`, contributors of both `TargetToken` and `Rewards` can retrieve their supplied tokens.