// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

// Tier layout used for tier-lookup and interpolation tests:
//   tier 0: payoutCount=2, payouts [1 ether, 2 ether]       — payoutNumbers 1–2
//   tier 1: payoutCount=2, payouts [6 ether, 8 ether]       — payoutNumbers 3–4
//   tier 2: payoutCount=4, payouts [20..50 ether] (step 10) — payoutNumbers 5–8
//
// Interpolation layout:
//   tier 0: payoutCount=1, payout = 1 ether                 — payoutNumber 1
//   tier 1: payoutCount=3, payouts [0..2 ether]             — payoutNumbers 2–4
contract RipsMath_CalculateEntryPayout is RipsTestBase {
    uint256 private constant HALF_UINT128 = type(uint128).max;

    uint256 private constant PAYOUT_1 = 1 ether;
    uint256 private constant PAYOUT_2 = 2 ether;
    uint256 private constant PAYOUT_3 = 6 ether;
    uint256 private constant PAYOUT_4 = 8 ether;
    uint256 private constant PAYOUT_5 = 20 ether;
    uint256 private constant PAYOUT_6 = 30 ether;
    uint256 private constant PAYOUT_7 = 40 ether;
    uint256 private constant PAYOUT_8 = 50 ether;

    uint256 private constant SINGLE_PAYOUT = 1 ether;
    uint256 private constant RANGE_MIN_PAYOUT = 0;
    uint256 private constant RANGE_MAX_PAYOUT = 2 ether;

    function _tierLookupTiers() private pure returns (IRips.PayoutTier[] memory tiers) {
        tiers = new IRips.PayoutTier[](3);
        tiers[0] = IRips.PayoutTier({payoutCount: 2, minPayout: uint128(PAYOUT_1), maxPayout: uint128(PAYOUT_2)});
        tiers[1] = IRips.PayoutTier({payoutCount: 2, minPayout: uint128(PAYOUT_3), maxPayout: uint128(PAYOUT_4)});
        tiers[2] = IRips.PayoutTier({payoutCount: 4, minPayout: uint128(PAYOUT_5), maxPayout: uint128(PAYOUT_8)});
    }

    function _tierLookupBoundaries() private pure returns (uint64[] memory b) {
        b = new uint64[](3);
        b[0] = 2;
        b[1] = 4;
        b[2] = 8;
    }

    function _interpolationTiers() private pure returns (IRips.PayoutTier[] memory tiers) {
        tiers = new IRips.PayoutTier[](2);
        tiers[0] =
            IRips.PayoutTier({payoutCount: 1, minPayout: uint128(SINGLE_PAYOUT), maxPayout: uint128(SINGLE_PAYOUT)});
        tiers[1] = IRips.PayoutTier({
            payoutCount: 3, minPayout: uint128(RANGE_MIN_PAYOUT), maxPayout: uint128(RANGE_MAX_PAYOUT)
        });
    }

    function _interpolationBoundaries() private pure returns (uint64[] memory b) {
        b = new uint64[](2);
        b[0] = 1;
        b[1] = 4;
    }

    // Use a=1, b=0 with entryNumber=(payoutNumber-1) so payoutNumber == desired.
    // Formula: (1 * (payoutNumber-1) + 0) % n + 1 == payoutNumber.
    function _identity(uint256 payoutNumber, IRips.PayoutTier[] memory tiers, uint64[] memory bounds)
        private
        view
        returns (uint256)
    {
        uint256 n = bounds[bounds.length - 1];
        return rips.exposed_calculateEntryPayout(payoutNumber - 1, 1, 0, uint64(n), tiers, bounds);
    }

    // ── Payout number properties ──────────────────────────────────────────────

    function test_ResultPayoutNumberIsAlwaysBetween1AndNInclusive(
        uint256 entryNumber,
        uint256 a,
        uint256 b,
        uint8 exponent
    ) external view {
        vm.assume(exponent > 0 && exponent < 64);
        uint256 n = 2 ** exponent;

        vm.assume(a <= HALF_UINT128 && entryNumber <= HALF_UINT128 && b <= HALF_UINT128);
        vm.assume(a % 2 != 0);

        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](1);
        tiers[0] = IRips.PayoutTier({payoutCount: uint64(n), minPayout: 1 ether, maxPayout: 1 ether});

        uint64[] memory boundaries = new uint64[](1);
        boundaries[0] = uint64(n);

        // All payouts are equal so the result must equal 1 ether regardless of payoutNumber.
        assertEq(
            rips.exposed_calculateEntryPayout(entryNumber, uint64(a), uint64(b), uint64(n), tiers, boundaries), 1 ether
        );
    }

    function test_DifferentEntryNumbersProduceDifferentPayoutNumbers(
        uint256 entryA,
        uint256 entryB,
        uint256 a,
        uint8 exponent
    ) external view {
        vm.assume(exponent > 0 && exponent < 64);
        uint256 n = 2 ** exponent;

        vm.assume(a <= HALF_UINT128 && entryA <= HALF_UINT128 && entryB <= HALF_UINT128);
        vm.assume(entryA % n != entryB % n);
        vm.assume(a % 2 != 0);

        // Use a range tier so each rank produces a distinct payout amount.
        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](1);
        tiers[0] = IRips.PayoutTier({payoutCount: uint64(n), minPayout: 0, maxPayout: uint128(n - 1) * 1 ether});

        uint64[] memory boundaries = new uint64[](1);
        boundaries[0] = uint64(n);

        uint256 payoutA = rips.exposed_calculateEntryPayout(entryA, uint64(a), 0, uint64(n), tiers, boundaries);
        uint256 payoutB = rips.exposed_calculateEntryPayout(entryB, uint64(a), 0, uint64(n), tiers, boundaries);

        assertNotEq(payoutA, payoutB);
    }

    // ── Never reverts ────────────────────────────────────────────────────────

    function test_ShouldNeverRevertForValidInputs(
        uint8 exponent,
        uint8 numTiersFuzz,
        uint128 payoutPerEntry,
        uint256 entryNumber
    ) external view {
        uint256 n = 1 << (exponent % 8 == 0 ? 1 : exponent % 8);
        uint256 numTiers = bound(uint256(numTiersFuzz), 1, n);

        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](numTiers);
        uint64[] memory boundaries = new uint64[](numTiers);

        uint256 remaining = n;
        uint64 cumulative = 0;

        for (uint256 i = 0; i < numTiers; i++) {
            uint256 payoutCount = (i == numTiers - 1) ? remaining : remaining / (numTiers - i);
            remaining -= payoutCount;
            cumulative += uint64(payoutCount);

            tiers[i] = IRips.PayoutTier({
                payoutCount: uint64(payoutCount), minPayout: payoutPerEntry, maxPayout: payoutPerEntry
            });
            boundaries[i] = cumulative;
        }

        rips.exposed_calculateEntryPayout(bound(entryNumber, 0, n - 1), 1, 0, uint64(n), tiers, boundaries);
    }

    // ── Tier lookup ──────────────────────────────────────────────────────────

    function test_WhenThePayoutNumberFallsInTheFirstTier() external view {
        assertEq(_identity(1, _tierLookupTiers(), _tierLookupBoundaries()), PAYOUT_1);
        assertEq(_identity(2, _tierLookupTiers(), _tierLookupBoundaries()), PAYOUT_2);
    }

    function test_WhenThePayoutNumberFallsInAMiddleTier() external view {
        assertEq(_identity(3, _tierLookupTiers(), _tierLookupBoundaries()), PAYOUT_3);
        assertEq(_identity(4, _tierLookupTiers(), _tierLookupBoundaries()), PAYOUT_4);
    }

    function test_WhenThePayoutNumberFallsInTheLastTier() external view {
        assertEq(_identity(5, _tierLookupTiers(), _tierLookupBoundaries()), PAYOUT_5);
        assertEq(_identity(6, _tierLookupTiers(), _tierLookupBoundaries()), PAYOUT_6);
        assertEq(_identity(7, _tierLookupTiers(), _tierLookupBoundaries()), PAYOUT_7);
        assertEq(_identity(8, _tierLookupTiers(), _tierLookupBoundaries()), PAYOUT_8);
    }

    // ── Single-payout tier ────────────────────────────────────────────────────

    function test_WhenTheTierHasASinglePayout() external view {
        assertEq(_identity(1, _interpolationTiers(), _interpolationBoundaries()), SINGLE_PAYOUT);
    }

    // ── Multi-payout tier interpolation ───────────────────────────────────────

    function test_WhenTheRankIsFirstInTheTier() external view {
        // tier 1 starts at payoutNumber 2 (rank 1 within tier)
        assertEq(_identity(2, _interpolationTiers(), _interpolationBoundaries()), RANGE_MIN_PAYOUT);
    }

    function test_WhenTheRankIsLastInTheTier() external view {
        // tier 1 ends at payoutNumber 4 (rank 3 within tier)
        assertEq(_identity(4, _interpolationTiers(), _interpolationBoundaries()), RANGE_MAX_PAYOUT);
    }

    function test_WhenTheRankIsInTheMiddleOfTheTier() external view {
        // tier 1: 3 payouts [0, 1, 2] ether; payoutNumber 3 is rank 2 → 1 ether
        assertEq(_identity(3, _interpolationTiers(), _interpolationBoundaries()), 1 ether);
    }
}
