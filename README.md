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
