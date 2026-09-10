// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

// Payouts interpolate with integer division, so each entry is floored and a rip
// pays out slightly less than the pool its config declares. Two properties must
// hold for every config, because the contract holds exactly one pool per rip:
//   1. payouts never exceed the pool, or the last claimant could not be paid
//   2. the shortfall stays within entryCap / 2, the bound MIN_ENTRY_PRICE assumes
contract RipsMath_PayoutDust is RipsTestBase {
    uint64 private constant MAX_FUZZ_ENTRY_CAP = 1024;

    // a million ether, so tier payouts stay far below the uint128 they are stored in
    // even once a tier's min and max are added together
    uint128 private constant MAX_FUZZ_PAYOUT = 1e24;

    // a is coprime with n and b shifts it, so entry -> payoutNumber is a bijection;
    // summing over every entry therefore visits every payout exactly once
    uint64 private constant IDENTITY_A = 1;
    uint64 private constant IDENTITY_B = 0;

    function _buildTiers(uint64 entryCap, uint64 tierCount, uint256 seed)
        private
        pure
        returns (IRips.PayoutTier[] memory tiers, uint64[] memory boundaries, uint256 pool)
    {
        tiers = new IRips.PayoutTier[](tierCount);
        boundaries = new uint64[](tierCount);

        uint64 remaining = entryCap;
        uint64 cumulative = 0;

        for (uint64 i = 0; i < tierCount; i++) {
            uint64 tiersLeft = tierCount - i - 1;

            // leave one entry for each remaining tier so every payoutCount stays non-zero
            uint64 count = tiersLeft == 0 ? remaining : uint64(seed % (remaining - tiersLeft)) + 1;
            seed = uint256(keccak256(abi.encode(seed)));

            uint128 minPayout = uint128(seed % MAX_FUZZ_PAYOUT);
            seed = uint256(keccak256(abi.encode(seed)));

            uint128 maxPayout = count == 1 ? minPayout : minPayout + uint128(seed % MAX_FUZZ_PAYOUT);
            seed = uint256(keccak256(abi.encode(seed)));

            tiers[i] = IRips.PayoutTier({payoutCount: count, minPayout: minPayout, maxPayout: maxPayout});

            // the pool a config declares, mirroring _validateConfig's average-based sum
            pool += (uint256(count) * (uint256(minPayout) + uint256(maxPayout))) / 2;

            cumulative += count;
            boundaries[i] = cumulative;

            remaining -= count;
        }
    }

    function _sumPayouts(uint64 entryCap, IRips.PayoutTier[] memory tiers, uint64[] memory boundaries)
        private
        pure
        returns (uint256 total)
    {
        for (uint64 entry = 1; entry <= entryCap; entry++) {
            total += RipsMath.calculateEntryPayout(entry, IDENTITY_A, IDENTITY_B, entryCap, tiers, boundaries);
        }
    }

    function testFuzz_PayoutsNeverExceedThePoolAndDustStaysBounded(
        uint64 rawEntryCap,
        uint64 rawTierCount,
        uint256 seed
    ) external pure {
        uint64 entryCap = uint64(bound(rawEntryCap, 1, MAX_FUZZ_ENTRY_CAP));
        uint64 tierCount = uint64(bound(rawTierCount, 1, entryCap < 16 ? entryCap : 16));

        (IRips.PayoutTier[] memory tiers, uint64[] memory boundaries, uint256 pool) =
            _buildTiers(entryCap, tierCount, seed);

        uint256 paid = _sumPayouts(entryCap, tiers, boundaries);

        assertLe(paid, pool, "payouts exceeded the pool");
        assertLe(pool - paid, uint256(entryCap) / 2, "dust exceeded entryCap / 2");
    }
}
