// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract RipsReferral_CollectReferrerFee is RipsTestBase {
    event ReferralStateUpdated(
        address indexed referrer, address indexed currency, IRips.ReferrerState referrerState
    );

    uint256 internal constant PROTOCOL_FEE = 1 ether;
    uint256 internal constant TICKET_REVENUE = 10 ether;

    uint16 internal constant DEFAULT_FEE = 500; // 5%
    uint16 internal constant TIER_LOW_FEE = 300; // 3%
    uint16 internal constant TIER_HIGH_FEE = 1000; // 10%
    uint16 internal constant CUSTOM_FEE = 800; // 8%

    uint128 internal constant TIER_LOW_MIN_VOLUME = 5 ether;
    uint128 internal constant TIER_HIGH_MIN_VOLUME = 50 ether;

    address internal constant CURRENCY = address(0);

    address internal referrerB = makeAddr("referrerB");

    uint40 internal periodStart;

    function setUp() public override {
        super.setUp();
        periodStart = uint40(rips.REFERRAL_PERIOD());
        vm.warp(periodStart);
    }

    function _setDefaultFee(uint16 fee) internal {
        vm.prank(owner);
        rips.setDefaultReferralFee(fee);
    }

    function _setTiers() internal {
        IRips.ReferralTier[] memory tiers = new IRips.ReferralTier[](2);
        tiers[0] = IRips.ReferralTier({minVolume: TIER_LOW_MIN_VOLUME, feePercent: TIER_LOW_FEE});
        tiers[1] = IRips.ReferralTier({minVolume: TIER_HIGH_MIN_VOLUME, feePercent: TIER_HIGH_FEE});

        vm.prank(owner);
        rips.setReferralTiers(CURRENCY, tiers);
    }

    function _setCustomFee(address _referrer, uint16 fee) internal {
        vm.prank(owner);
        rips.setReferrerCustomFee(_referrer, fee);
    }

    function _advanceToNextPeriod() internal {
        vm.warp(block.timestamp + rips.REFERRAL_PERIOD() + 1);
    }

    function test_WhenReferrerIsZeroAddress() external {
        // it should return zero.
        uint256 fee =
            rips.exposed_collectReferrerFee(address(0), CURRENCY, PROTOCOL_FEE, TICKET_REVENUE);

        assertEq(fee, 0);
    }

    function test_WhenReferrerHasACustomFeeSet() external {
        // it should return fee based on custom fee percent.
        // it should update referrer state the same as the tier path.
        // it should emit a {ReferralStateUpdated} event.
        _setDefaultFee(DEFAULT_FEE);
        _setTiers();

        // period 1: accumulate volume above high tier threshold
        uint256 volumeAboveHighTier = uint256(TIER_HIGH_MIN_VOLUME) + 1 ether;
        rips.exposed_collectReferrerFee(referrer, CURRENCY, PROTOCOL_FEE, volumeAboveHighTier);

        _advanceToNextPeriod();

        // custom fee is set — activeFeePercent is still resolved from tiers but ignored for fee calc
        _setCustomFee(referrer, CUSTOM_FEE);

        uint256 expectedFee = (PROTOCOL_FEE * CUSTOM_FEE) / rips.FEE_BASE();

        vm.expectEmit();
        emit ReferralStateUpdated(
            referrer,
            CURRENCY,
            IRips.ReferrerState({
                activeFeePercent: TIER_HIGH_FEE,
                periodStartTimestamp: 2 * periodStart,
                periodVolume: TICKET_REVENUE
            })
        );

        uint256 fee =
            rips.exposed_collectReferrerFee(referrer, CURRENCY, PROTOCOL_FEE, TICKET_REVENUE);

        assertEq(fee, expectedFee);

        IRips.ReferrerState memory stats = rips.exposed_referrerStats(referrer, CURRENCY);
        assertEq(stats.periodVolume, TICKET_REVENUE);
        assertEq(stats.activeFeePercent, TIER_HIGH_FEE);
        assertEq(rips.referrerCustomFee(referrer), CUSTOM_FEE);
    }

    function test_WhenReferrerHasACustomFeeSet_AndANewPeriodStarts() external {
        // it should reset periodVolume to the current revenue.
        // it should advance periodStartTimestamp to the current period.
        // it should emit a {ReferralStateUpdated} event.
        _setCustomFee(referrer, CUSTOM_FEE);

        rips.exposed_collectReferrerFee(referrer, CURRENCY, PROTOCOL_FEE, TICKET_REVENUE);

        _advanceToNextPeriod();

        vm.expectEmit();
        emit ReferralStateUpdated(
            referrer,
            CURRENCY,
            IRips.ReferrerState({
                activeFeePercent: 0,
                periodStartTimestamp: 2 * periodStart,
                periodVolume: TICKET_REVENUE
            })
        );

        uint256 fee =
            rips.exposed_collectReferrerFee(referrer, CURRENCY, PROTOCOL_FEE, TICKET_REVENUE);

        assertEq(fee, (PROTOCOL_FEE * CUSTOM_FEE) / rips.FEE_BASE());

        IRips.ReferrerState memory stats = rips.exposed_referrerStats(referrer, CURRENCY);
        assertEq(stats.periodVolume, TICKET_REVENUE);
        assertEq(stats.periodStartTimestamp, 2 * periodStart);
    }

    function test_WhenReferrerAppearsForTheFirstTime() external {
        // it should set periodStartTimestamp to block.timestamp.
        // it should set periodVolume to the current revenue.
        // it should treat the next call within the period as the same period.
        _setDefaultFee(DEFAULT_FEE);
        _setTiers();

        uint40 firstAppearance = periodStart * 100 + 13 days; // not a clean multiple of REFERRAL_PERIOD
        vm.warp(firstAppearance);

        rips.exposed_collectReferrerFee(referrer, CURRENCY, PROTOCOL_FEE, TICKET_REVENUE);

        IRips.ReferrerState memory statsAfterFirst = rips.exposed_referrerStats(referrer, CURRENCY);
        assertEq(statsAfterFirst.periodStartTimestamp, firstAppearance);
        assertEq(statsAfterFirst.periodVolume, TICKET_REVENUE);

        // second call shortly after — same period, volume should accumulate
        vm.warp(firstAppearance + 1 days);

        rips.exposed_collectReferrerFee(referrer, CURRENCY, PROTOCOL_FEE, TICKET_REVENUE);

        IRips.ReferrerState memory statsAfterSecond = rips.exposed_referrerStats(referrer, CURRENCY);
        assertEq(statsAfterSecond.periodStartTimestamp, firstAppearance);
        assertEq(statsAfterSecond.periodVolume, 2 * TICKET_REVENUE);
    }

    function test_WhenNoReferralTiersAreConfiguredAndDefaultFeeIsZero() external {
        // it should return zero.
        // it should update only periodVolume.
        // it should emit a {ReferralStateUpdated} event.
        vm.expectEmit();
        emit ReferralStateUpdated(
            referrer,
            CURRENCY,
            IRips.ReferrerState({
                activeFeePercent: 0, periodStartTimestamp: periodStart, periodVolume: TICKET_REVENUE
            })
        );

        uint256 fee =
            rips.exposed_collectReferrerFee(referrer, CURRENCY, PROTOCOL_FEE, TICKET_REVENUE);

        assertEq(fee, 0);

        IRips.ReferrerState memory stats = rips.exposed_referrerStats(referrer, CURRENCY);
        assertEq(stats.periodVolume, TICKET_REVENUE);
        assertEq(stats.activeFeePercent, 0);
    }

    function test_WhenDefaultFeeIsSetAndReferrerHasNoPriorActivity() external {
        // it should return fee based on default fee percent.
        // it should update only periodVolume.
        // it should emit a {ReferralStateUpdated} event.
        _setDefaultFee(DEFAULT_FEE);

        uint256 expectedFee = (PROTOCOL_FEE * DEFAULT_FEE) / rips.FEE_BASE();

        vm.expectEmit();
        emit ReferralStateUpdated(
            referrer,
            CURRENCY,
            IRips.ReferrerState({
                activeFeePercent: 0, periodStartTimestamp: periodStart, periodVolume: TICKET_REVENUE
            })
        );

        uint256 fee =
            rips.exposed_collectReferrerFee(referrer, CURRENCY, PROTOCOL_FEE, TICKET_REVENUE);

        assertEq(fee, expectedFee);

        IRips.ReferrerState memory stats = rips.exposed_referrerStats(referrer, CURRENCY);
        assertEq(stats.periodVolume, TICKET_REVENUE);
        assertEq(stats.activeFeePercent, 0);
    }

    function test_WhenReferrerCurrentPeriodVolumeCrossesATierThreshold() external {
        // it should return fee based on default fee percent.
        // it should update only periodVolume.
        // it should emit a {ReferralStateUpdated} event.
        _setDefaultFee(DEFAULT_FEE);
        _setTiers();

        // push referrer's current period volume above the low tier threshold
        uint256 volumeAboveTier = uint256(TIER_LOW_MIN_VOLUME) + 1 ether;

        uint256 expectedFee = (PROTOCOL_FEE * DEFAULT_FEE) / rips.FEE_BASE();

        vm.expectEmit();
        emit ReferralStateUpdated(
            referrer,
            CURRENCY,
            IRips.ReferrerState({
                activeFeePercent: 0,
                periodStartTimestamp: periodStart,
                periodVolume: volumeAboveTier
            })
        );

        uint256 fee =
            rips.exposed_collectReferrerFee(referrer, CURRENCY, PROTOCOL_FEE, volumeAboveTier);

        assertEq(fee, expectedFee);

        IRips.ReferrerState memory stats = rips.exposed_referrerStats(referrer, CURRENCY);
        assertEq(stats.periodVolume, volumeAboveTier);
        // active fee is not updated mid-period; tier is only applied next period
        assertEq(stats.activeFeePercent, 0);
    }

    function test_WhenReferrersPreviousPeriodVolumeReachedATierThreshold() external {
        // it should return fee based on active fee percent.
        // it should update referrerStats.
        // it should emit a {ReferralStateUpdated} event.
        _setDefaultFee(DEFAULT_FEE);
        _setTiers();

        // cross high tier threshold in period 1 (TIER_HIGH_FEE 10% > DEFAULT_FEE 5%)
        uint256 volumeAboveHighTier = uint256(TIER_HIGH_MIN_VOLUME) + 1 ether;
        rips.exposed_collectReferrerFee(referrer, CURRENCY, PROTOCOL_FEE, volumeAboveHighTier);

        _advanceToNextPeriod();

        // period 2: previous period volume unlocks high tier fee
        uint256 expectedFee = (PROTOCOL_FEE * TIER_HIGH_FEE) / rips.FEE_BASE();

        vm.expectEmit();
        emit ReferralStateUpdated(
            referrer,
            CURRENCY,
            IRips.ReferrerState({
                activeFeePercent: TIER_HIGH_FEE,
                periodStartTimestamp: 2 * periodStart,
                periodVolume: TICKET_REVENUE
            })
        );

        uint256 fee =
            rips.exposed_collectReferrerFee(referrer, CURRENCY, PROTOCOL_FEE, TICKET_REVENUE);

        assertEq(fee, expectedFee);

        IRips.ReferrerState memory stats = rips.exposed_referrerStats(referrer, CURRENCY);
        assertEq(stats.activeFeePercent, TIER_HIGH_FEE);
    }

    function test_WhenActiveFeePercentIsBelowDefaultFeePercent() external {
        // it should return fee based on default fee percent.
        // it should update only periodVolume.
        // it should emit a {ReferralStateUpdated} event.

        // TIER_LOW_FEE (3%) < DEFAULT_FEE (5%), so default should win
        _setDefaultFee(DEFAULT_FEE);
        _setTiers();

        // cross low tier threshold in period 1
        uint256 volumeAboveTier = uint256(TIER_LOW_MIN_VOLUME) + 1 ether;
        rips.exposed_collectReferrerFee(referrer, CURRENCY, PROTOCOL_FEE, volumeAboveTier);

        _advanceToNextPeriod();

        // period 2: active fee (3%) is below default (5%), default wins
        uint256 expectedFee = (PROTOCOL_FEE * DEFAULT_FEE) / rips.FEE_BASE();

        vm.expectEmit();
        emit ReferralStateUpdated(
            referrer,
            CURRENCY,
            IRips.ReferrerState({
                activeFeePercent: TIER_LOW_FEE,
                periodStartTimestamp: 2 * periodStart,
                periodVolume: TICKET_REVENUE
            })
        );

        uint256 fee =
            rips.exposed_collectReferrerFee(referrer, CURRENCY, PROTOCOL_FEE, TICKET_REVENUE);

        assertEq(fee, expectedFee);
    }

    function test_WhenANewPeriodStartsAfterAConsecutiveActivePeriod() external {
        // it should update referrerStats.
        // it should emit a {ReferralStateUpdated} event.
        _setDefaultFee(DEFAULT_FEE);
        _setTiers();

        // period 1: cross tier threshold
        uint256 volumeAboveTier = uint256(TIER_LOW_MIN_VOLUME) + 1 ether;
        rips.exposed_collectReferrerFee(referrer, CURRENCY, PROTOCOL_FEE, volumeAboveTier);

        _advanceToNextPeriod();

        // period 2: active, cross tier threshold again
        rips.exposed_collectReferrerFee(referrer, CURRENCY, PROTOCOL_FEE, volumeAboveTier);

        IRips.ReferrerState memory statsAfterPeriod2 =
            rips.exposed_referrerStats(referrer, CURRENCY);
        assertEq(statsAfterPeriod2.activeFeePercent, TIER_LOW_FEE);
        assertEq(statsAfterPeriod2.periodVolume, volumeAboveTier);

        _advanceToNextPeriod();

        // period 3: new period starts, stats should roll over correctly
        vm.expectEmit();
        emit ReferralStateUpdated(
            referrer,
            CURRENCY,
            IRips.ReferrerState({
                activeFeePercent: TIER_LOW_FEE,
                periodStartTimestamp: 3 * periodStart,
                periodVolume: TICKET_REVENUE
            })
        );

        rips.exposed_collectReferrerFee(referrer, CURRENCY, PROTOCOL_FEE, TICKET_REVENUE);

        IRips.ReferrerState memory statsAfterPeriod3 =
            rips.exposed_referrerStats(referrer, CURRENCY);
        assertEq(statsAfterPeriod3.activeFeePercent, TIER_LOW_FEE);
        assertEq(statsAfterPeriod3.periodVolume, TICKET_REVENUE);
    }

    function test_WhenANewPeriodStartsAfterAnInactivePeriodGap() external {
        // it should update referrerStats.
        // it should reset active fee percent to zero.
        // it should emit a {ReferralStateUpdated} event.
        _setDefaultFee(DEFAULT_FEE);
        _setTiers();

        // period 1: cross tier threshold
        uint256 volumeAboveTier = uint256(TIER_LOW_MIN_VOLUME) + 1 ether;
        rips.exposed_collectReferrerFee(referrer, CURRENCY, PROTOCOL_FEE, volumeAboveTier);

        _advanceToNextPeriod();

        // period 2: active — unlocks tier fee, but skip period 3
        rips.exposed_collectReferrerFee(referrer, CURRENCY, PROTOCOL_FEE, volumeAboveTier);

        // skip two full periods (gap — period 3 is inactive)
        vm.warp(block.timestamp + 2 * rips.REFERRAL_PERIOD() + 1);

        // period 4: gap means active fee resets to zero
        vm.expectEmit();
        emit ReferralStateUpdated(
            referrer,
            CURRENCY,
            IRips.ReferrerState({
                activeFeePercent: 0,
                periodStartTimestamp: 4 * periodStart,
                periodVolume: TICKET_REVENUE
            })
        );

        rips.exposed_collectReferrerFee(referrer, CURRENCY, PROTOCOL_FEE, TICKET_REVENUE);

        IRips.ReferrerState memory stats = rips.exposed_referrerStats(referrer, CURRENCY);
        assertEq(stats.activeFeePercent, 0);
        assertEq(stats.periodVolume, TICKET_REVENUE);
        assertEq(stats.periodStartTimestamp, 4 * periodStart);
    }

    function test_WhenTwoReferrersHaveIndependentPeriodTracking() external {
        // it should apply tier fee to referrer A after their period ends.
        // it should apply default fee to referrer B whose period has not yet ended.
        // it should emit a {ReferralStateUpdated} event for each referrer.
        _setDefaultFee(DEFAULT_FEE);
        _setTiers();

        uint256 volumeAboveHighTier = uint256(TIER_HIGH_MIN_VOLUME) + 1 ether;

        // referrer A claims in period 1 with high volume
        rips.exposed_collectReferrerFee(referrer, CURRENCY, PROTOCOL_FEE, volumeAboveHighTier);

        _advanceToNextPeriod();

        // referrer B makes their first claim at the start of referrer A's period 2
        rips.exposed_collectReferrerFee(referrerB, CURRENCY, PROTOCOL_FEE, volumeAboveHighTier);

        // referrer A: period 2 — previous period volume unlocks TIER_HIGH_FEE
        vm.expectEmit();
        emit ReferralStateUpdated(
            referrer,
            CURRENCY,
            IRips.ReferrerState({
                activeFeePercent: TIER_HIGH_FEE,
                periodStartTimestamp: 2 * periodStart,
                periodVolume: TICKET_REVENUE
            })
        );

        uint256 feeA =
            rips.exposed_collectReferrerFee(referrer, CURRENCY, PROTOCOL_FEE, TICKET_REVENUE);
        assertEq(feeA, (PROTOCOL_FEE * TIER_HIGH_FEE) / rips.FEE_BASE());

        IRips.ReferrerState memory statsA = rips.exposed_referrerStats(referrer, CURRENCY);
        assertEq(statsA.activeFeePercent, TIER_HIGH_FEE);

        // referrer B: still in their first period — no previous period volume yet, default fee applies
        // B's period started at block.timestamp when they first appeared (2 * periodStart + 1)
        uint40 referrerBPeriodStart = 2 * periodStart + 1;
        vm.expectEmit();
        emit ReferralStateUpdated(
            referrerB,
            CURRENCY,
            IRips.ReferrerState({
                activeFeePercent: 0,
                periodStartTimestamp: referrerBPeriodStart,
                periodVolume: volumeAboveHighTier + TICKET_REVENUE
            })
        );

        uint256 feeB =
            rips.exposed_collectReferrerFee(referrerB, CURRENCY, PROTOCOL_FEE, TICKET_REVENUE);
        assertEq(feeB, (PROTOCOL_FEE * DEFAULT_FEE) / rips.FEE_BASE());

        IRips.ReferrerState memory statsB = rips.exposed_referrerStats(referrerB, CURRENCY);
        assertEq(statsB.activeFeePercent, 0);
    }

    function test_WhenTwoCurrenciesHaveIndependentVolumeTracking() external {
        // it should track volume separately per currency.
        // it should apply tiers independently per currency.
        _setDefaultFee(DEFAULT_FEE);

        address currencyA = address(0);
        address currencyB = makeAddr("currencyB");

        IRips.ReferralTier[] memory tiersA = new IRips.ReferralTier[](1);
        tiersA[0] = IRips.ReferralTier({minVolume: TIER_HIGH_MIN_VOLUME, feePercent: TIER_HIGH_FEE});

        IRips.ReferralTier[] memory tiersB = new IRips.ReferralTier[](1);
        tiersB[0] = IRips.ReferralTier({minVolume: TIER_LOW_MIN_VOLUME, feePercent: TIER_LOW_FEE});

        vm.startPrank(owner);
        rips.setReferralTiers(currencyA, tiersA);
        rips.setReferralTiers(currencyB, tiersB);
        vm.stopPrank();

        uint256 volumeAboveHighTier = uint256(TIER_HIGH_MIN_VOLUME) + 1 ether;

        // period 1: high volume in currency A, no activity in currency B
        rips.exposed_collectReferrerFee(referrer, currencyA, PROTOCOL_FEE, volumeAboveHighTier);

        _advanceToNextPeriod();

        // period 2: currency A unlocks TIER_HIGH_FEE, currency B has no prior volume
        uint256 feeA =
            rips.exposed_collectReferrerFee(referrer, currencyA, PROTOCOL_FEE, TICKET_REVENUE);
        uint256 feeB =
            rips.exposed_collectReferrerFee(referrer, currencyB, PROTOCOL_FEE, TICKET_REVENUE);

        assertEq(feeA, (PROTOCOL_FEE * TIER_HIGH_FEE) / rips.FEE_BASE());
        assertEq(feeB, (PROTOCOL_FEE * DEFAULT_FEE) / rips.FEE_BASE());

        IRips.ReferrerState memory statsA = rips.exposed_referrerStats(referrer, currencyA);
        IRips.ReferrerState memory statsB = rips.exposed_referrerStats(referrer, currencyB);

        assertEq(statsA.activeFeePercent, TIER_HIGH_FEE);
        assertEq(statsB.activeFeePercent, 0);
    }
}
