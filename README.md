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

### A claimer can pass their own address as the referrer

`claimPayout` takes `referrer` as a free argument, and `_collectReferrerFee` only rejects the zero address. Anyone claiming for themselves can therefore name themselves as the referrer and take back the referral share of the protocol fee on their own entries, and credit their own `periodVolume` toward a higher referral tier. Nobody else's payout or fee is touched — the loss is limited to part of the fee that claimer paid. `OPERATOR_ROLE` can claim on any user's behalf and pick the referrer independently, so it can direct the referral share of every claim to an address of its choosing; that role is trusted.

There is nothing to recover, because no funds are ever stuck or taken from another account. Once an abusing address is spotted, an admin calls `setReferrerFrozen` to block its `withdrawReferrerFee`, then `seizeReferrerFee` to move the accrued balance to `feeRecipient`. Both act on one address at a time, so someone who keeps switching addresses keeps earning until each new one is caught — they are a response to abuse, not a guard on the referral system.

We accept this rather than fix it. Whoever claims decides who gets the referral credit, and that is the intended behaviour — the user chooses whether to use a referrer at all. Rejecting `referrer == recipient` would not close it either: the same person just claims from one address and names a second one they control. A trusted-referrer list has the same hole, since a user can register themselves. In practice entries come through our own frontends, which pass the correct referrer; a user who builds the transaction by hand only reduces the fee they themselves paid.

### A referrer can withdraw before an admin freezes them

`withdrawReferrerFee` is permissionless and has no delay between accrual and withdrawal, so a referrer can claim and withdraw in the same transaction. `setReferrerFrozen` and `seizeReferrerFee` then find a zero balance. Freezing an address stops what it accrues from that point on, but whatever it already withdrew is gone — `seizeReferrerFee` only reaches a balance still sitting in the contract. Users are unaffected: a referrer withdraws their own accrued fee and no one else's payout or balance is touched.

There is nothing to recover, because the withdrawn amount was the referrer's own accrued fee. What limits the damage is the accrual side rather than the withdrawal side: `setDefaultReferralFee`, `setReferrerCustomFee`, and `setReferralTiers` all cap `feeBps` at `FEE_BASE` and are admin-only, so a referrer can never accrue more than the configured share of the protocol fee on entries they are named for.

We accept this rather than fix it. Freeze and seize are an admin tool for cutting off a referrer we judge to be abusing the programme, not a security control — they answer a bad actor, not an attacker, and there is no exploit for them to be too slow against. Adding a withdrawal delay would hold every honest referrer's fee hostage to a case that only matters after we have already decided to remove someone, and the referrer could still withdraw during the window before we noticed.

### Sold-out rip is stuck if `requestRandomness` reverts

When `requestRandomness` reverts inside Chainlink — a drained subscription, a de-registered consumer, a failing coordinator — a sold-out rip can neither draw a winner nor become refundable, and its funds stay locked. Only an admin can resolve this; users cannot recover on their own.

Recovery is always available. `requestRandomness` is permissionless and writes no state before the external call, so once an admin corrects the cause with `updateVrfSubscriptionId`, `setCoordinator`, or `updateVrfRequestConfirmations`, anyone can call it again.

We accept this rather than fix it. Nothing in the contract leads here; it takes an outright Chainlink failure. An automatic refund would mean gating `requestRandomness` behind a one-way switch, since otherwise randomness could still be fulfilled while refunds are draining — meaningful complexity in the payout path to cover a case that should never happen.
