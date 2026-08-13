# Rips Smart Contract

A prize protocol where users buy tickets for rounds, winners are selected via Chainlink VRF, and prizes are distributed across configurable tiers.

## Overview

- **Presets** define rip configurations (ticket price, cap, duration, prize tiers)
- **Rips** are created automatically per preset; users buy tickets within a rip
- **Chainlink VRF** provides verifiable randomness to finalize rounds
- **Prize tiers** support linear interpolation between min/max prizes
- **Refunds** are available for expired rounds that never filled

## Setup

```shell
forge install
```

## Testing

Uses [Forge](https://book.getfoundry.sh/) for tests and [Bulloak](https://github.com/alexfertel/bulloak) to scaffold/validate test structure from `.tree` spec files.

```shell
forge test
```

### Bulloak

`.tree` files in `test/` describe the expected test structure. Use `make` commands to manage them:

```shell
make scaffold   # generate test files from .tree specs
make check      # verify test files match .tree specs
make fix        # auto-fix mismatches and format
```

## Local Setup

Spins up a local Anvil node (chain ID 8453), deploys a mock VRF coordinator and the Rips contract, and writes deployment addresses to `local/state/deployments.json` for use by off-chain tooling.

```shell
make local
```

Output: `local/state/deployments.json` with `rips`, `vrfCoordinator`, and `subscriptionId`.

## Known Issues & Accepted Risks

Known to the team and accepted. Not valid audit findings. `DEFAULT_ADMIN_ROLE` and `OPERATOR_ROLE` are trusted to act honestly and stay available.

### Sold-out rip is stuck if `requestRandomness` reverts

When `requestRandomness` reverts inside Chainlink — a drained subscription, a de-registered consumer, a failing coordinator — a sold-out rip can neither draw a winner nor become refundable, and its funds stay locked. Only an admin can resolve this; users cannot recover on their own.

Recovery is always available. `requestRandomness` is permissionless and writes no state before the external call, so once an admin corrects the cause with `updateVrfSubscriptionId`, `setCoordinator`, or `updateVrfRequestConfirmations`, anyone can call it again.

We accept this rather than fix it. Nothing in the contract leads here; it takes an outright Chainlink failure. An automatic refund would mean gating `requestRandomness` behind a one-way switch, since otherwise randomness could still be fulfilled while refunds are draining — meaningful complexity in the payout path to cover a case that should never happen.
