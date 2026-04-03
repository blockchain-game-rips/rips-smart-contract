// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

// Tier layout used for tier-lookup and interpolation tests:
//   tier 0: prizeCount=2, prizes [1 ether, 2 ether]       — prizeNumbers 1–2
//   tier 1: prizeCount=2, prizes [6 ether, 8 ether]       — prizeNumbers 3–4
//   tier 2: prizeCount=4, prizes [20..50 ether] (step 10) — prizeNumbers 5–8
//
// Interpolation layout:
//   tier 0: prizeCount=1, prize = 1 ether                 — prizeNumber 1
//   tier 1: prizeCount=3, prizes [0..2 ether]             — prizeNumbers 2–4
contract RipsMath_CalculateTicketPrize is RipsTestBase {
    uint256 private constant HALF_UINT128 = type(uint128).max;

    uint256 private constant PRIZE_1 = 1 ether;
    uint256 private constant PRIZE_2 = 2 ether;
    uint256 private constant PRIZE_3 = 6 ether;
    uint256 private constant PRIZE_4 = 8 ether;
    uint256 private constant PRIZE_5 = 20 ether;
    uint256 private constant PRIZE_6 = 30 ether;
    uint256 private constant PRIZE_7 = 40 ether;
    uint256 private constant PRIZE_8 = 50 ether;

    uint256 private constant SINGLE_PRIZE = 1 ether;
    uint256 private constant RANGE_MIN_PRIZE = 0;
    uint256 private constant RANGE_MAX_PRIZE = 2 ether;

    function _tierLookupTiers() private pure returns (IRips.PrizeTier[] memory tiers) {
        tiers = new IRips.PrizeTier[](3);
        tiers[0] = IRips.PrizeTier({
            prizeCount: 2, minPrize: uint128(PRIZE_1), maxPrize: uint128(PRIZE_2)
        });
        tiers[1] = IRips.PrizeTier({
            prizeCount: 2, minPrize: uint128(PRIZE_3), maxPrize: uint128(PRIZE_4)
        });
        tiers[2] = IRips.PrizeTier({
            prizeCount: 4, minPrize: uint128(PRIZE_5), maxPrize: uint128(PRIZE_8)
        });
    }

    function _tierLookupBoundaries() private pure returns (uint64[] memory b) {
        b = new uint64[](3);
        b[0] = 2;
        b[1] = 4;
        b[2] = 8;
    }

    function _interpolationTiers() private pure returns (IRips.PrizeTier[] memory tiers) {
        tiers = new IRips.PrizeTier[](2);
        tiers[0] = IRips.PrizeTier({
            prizeCount: 1, minPrize: uint128(SINGLE_PRIZE), maxPrize: uint128(SINGLE_PRIZE)
        });
        tiers[1] = IRips.PrizeTier({
            prizeCount: 3, minPrize: uint128(RANGE_MIN_PRIZE), maxPrize: uint128(RANGE_MAX_PRIZE)
        });
    }

    function _interpolationBoundaries() private pure returns (uint64[] memory b) {
        b = new uint64[](2);
        b[0] = 1;
        b[1] = 4;
    }

    // Use a=1, b=0 with ticketNumber=(prizeNumber-1) so prizeNumber == desired.
    // Formula: (1 * (prizeNumber-1) + 0) % n + 1 == prizeNumber.
    function _identity(uint256 prizeNumber, IRips.PrizeTier[] memory tiers, uint64[] memory bounds)
        private
        view
        returns (uint256)
    {
        uint256 n = bounds[bounds.length - 1];
        return rips.exposed_calculateTicketPrize(prizeNumber - 1, 1, 0, uint64(n), tiers, bounds);
    }

    // ── Prize number properties ──────────────────────────────────────────────

    function test_ResultPrizeNumberIsAlwaysBetween1AndNInclusive(
        uint256 ticketNumber,
        uint256 a,
        uint256 b,
        uint8 exponent
    ) external view {
        vm.assume(exponent > 0 && exponent < 64);
        uint256 n = 2 ** exponent;

        vm.assume(a <= HALF_UINT128 && ticketNumber <= HALF_UINT128 && b <= HALF_UINT128);
        vm.assume(a % 2 != 0);

        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({prizeCount: uint64(n), minPrize: 1 ether, maxPrize: 1 ether});

        uint64[] memory boundaries = new uint64[](1);
        boundaries[0] = uint64(n);

        // All prizes are equal so the result must equal 1 ether regardless of prizeNumber.
        assertEq(
            rips.exposed_calculateTicketPrize(
                ticketNumber, uint64(a), uint64(b), uint64(n), tiers, boundaries
            ),
            1 ether
        );
    }

    function test_DifferentTicketNumbersProduceDifferentPrizeNumbers(
        uint256 ticketA,
        uint256 ticketB,
        uint256 a,
        uint8 exponent
    ) external view {
        vm.assume(exponent > 0 && exponent < 64);
        uint256 n = 2 ** exponent;

        vm.assume(a <= HALF_UINT128 && ticketA <= HALF_UINT128 && ticketB <= HALF_UINT128);
        vm.assume(ticketA % n != ticketB % n);
        vm.assume(a % 2 != 0);

        // Use a range tier so each rank produces a distinct prize amount.
        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: uint64(n), minPrize: 0, maxPrize: uint128(n - 1) * 1 ether
        });

        uint64[] memory boundaries = new uint64[](1);
        boundaries[0] = uint64(n);

        uint256 prizeA =
            rips.exposed_calculateTicketPrize(ticketA, uint64(a), 0, uint64(n), tiers, boundaries);
        uint256 prizeB =
            rips.exposed_calculateTicketPrize(ticketB, uint64(a), 0, uint64(n), tiers, boundaries);

        assertNotEq(prizeA, prizeB);
    }

    // ── Never reverts ────────────────────────────────────────────────────────

    function test_ShouldNeverRevertForValidInputs(
        uint8 exponent,
        uint8 numTiersFuzz,
        uint128 prizePerTicket,
        uint256 ticketNumber
    ) external view {
        uint256 n = 1 << (exponent % 8 == 0 ? 1 : exponent % 8);
        uint256 numTiers = bound(uint256(numTiersFuzz), 1, n);

        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](numTiers);
        uint64[] memory boundaries = new uint64[](numTiers);

        uint256 remaining = n;
        uint64 cumulative = 0;

        for (uint256 i = 0; i < numTiers; i++) {
            uint256 prizeCount = (i == numTiers - 1) ? remaining : remaining / (numTiers - i);
            remaining -= prizeCount;
            cumulative += uint64(prizeCount);

            tiers[i] = IRips.PrizeTier({
                prizeCount: uint64(prizeCount), minPrize: prizePerTicket, maxPrize: prizePerTicket
            });
            boundaries[i] = cumulative;
        }

        rips.exposed_calculateTicketPrize(
            bound(ticketNumber, 0, n - 1), 1, 0, uint64(n), tiers, boundaries
        );
    }

    // ── Tier lookup ──────────────────────────────────────────────────────────

    function test_WhenThePrizeNumberFallsInTheFirstTier() external view {
        assertEq(_identity(1, _tierLookupTiers(), _tierLookupBoundaries()), PRIZE_1);
        assertEq(_identity(2, _tierLookupTiers(), _tierLookupBoundaries()), PRIZE_2);
    }

    function test_WhenThePrizeNumberFallsInAMiddleTier() external view {
        assertEq(_identity(3, _tierLookupTiers(), _tierLookupBoundaries()), PRIZE_3);
        assertEq(_identity(4, _tierLookupTiers(), _tierLookupBoundaries()), PRIZE_4);
    }

    function test_WhenThePrizeNumberFallsInTheLastTier() external view {
        assertEq(_identity(5, _tierLookupTiers(), _tierLookupBoundaries()), PRIZE_5);
        assertEq(_identity(6, _tierLookupTiers(), _tierLookupBoundaries()), PRIZE_6);
        assertEq(_identity(7, _tierLookupTiers(), _tierLookupBoundaries()), PRIZE_7);
        assertEq(_identity(8, _tierLookupTiers(), _tierLookupBoundaries()), PRIZE_8);
    }

    // ── Single-prize tier ────────────────────────────────────────────────────

    function test_WhenTheTierHasASinglePrize() external view {
        assertEq(_identity(1, _interpolationTiers(), _interpolationBoundaries()), SINGLE_PRIZE);
    }

    // ── Multi-prize tier interpolation ───────────────────────────────────────

    function test_WhenTheRankIsFirstInTheTier() external view {
        // tier 1 starts at prizeNumber 2 (rank 1 within tier)
        assertEq(_identity(2, _interpolationTiers(), _interpolationBoundaries()), RANGE_MIN_PRIZE);
    }

    function test_WhenTheRankIsLastInTheTier() external view {
        // tier 1 ends at prizeNumber 4 (rank 3 within tier)
        assertEq(_identity(4, _interpolationTiers(), _interpolationBoundaries()), RANGE_MAX_PRIZE);
    }

    function test_WhenTheRankIsInTheMiddleOfTheTier() external view {
        // tier 1: 3 prizes [0, 1, 2] ether; prizeNumber 3 is rank 2 → 1 ether
        assertEq(_identity(3, _interpolationTiers(), _interpolationBoundaries()), 1 ether);
    }
}
