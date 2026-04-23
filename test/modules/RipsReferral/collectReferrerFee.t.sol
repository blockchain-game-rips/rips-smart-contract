// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract RipsReferral_CollectReferrerFee is RipsTestBase {
    event ReferralStatsUpdated(address indexed referrer, IRips.ReferrerState referrerState);
    uint256 internal constant PROTOCOL_FEE = 1 ether;
    uint256 internal constant TICKET_REVENUE = 10 ether;

    uint16 internal constant DEFAULT_FEE = 500; // 5%
    uint16 internal constant TIER_LOW_FEE = 300; // 3%
    uint16 internal constant TIER_HIGH_FEE = 1000; // 10%
    uint16 internal constant CUSTOM_FEE = 800; // 8%

    uint128 internal constant TIER_LOW_MIN_VOLUME = 5 ether;
    uint128 internal constant TIER_HIGH_MIN_VOLUME = 50 ether;

    address internal referrerB = makeAddr("referrerB");

    function _setDefaultFee(uint16 fee) internal {
        vm.prank(owner);
        rips.setDefaultReferralFee(fee);
    }

    function _setTiers() internal {
        IRips.ReferralTier[] memory tiers = new IRips.ReferralTier[](2);
        tiers[0] = IRips.ReferralTier({minVolume: TIER_LOW_MIN_VOLUME, feePercent: TIER_LOW_FEE});
        tiers[1] = IRips.ReferralTier({minVolume: TIER_HIGH_MIN_VOLUME, feePercent: TIER_HIGH_FEE});

        vm.prank(owner);
        rips.setReferralTiers(tiers);
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
        uint256 fee = rips.exposed_collectReferrerFee(address(0), PROTOCOL_FEE, TICKET_REVENUE);

        assertEq(fee, 0);
    }

    function test_WhenReferrerHasACustomFeeSet() external {
        // it should return fee based on custom fee percent.
        // it should update only currMonthVolume.
        // it should emit a {ReferralStatsUpdated} event.
        _setCustomFee(referrer, CUSTOM_FEE);

        uint256 expectedFee = (PROTOCOL_FEE * CUSTOM_FEE) / rips.FEE_BASE();

        vm.expectEmit();
        emit ReferralStatsUpdated(
            referrer,
            IRips.ReferrerState({
                activeFeePercent: 0,
                customFeePercent: CUSTOM_FEE,
                monthStartTimestamp: 0,
                currMonthVolume: TICKET_REVENUE
            })
        );

        uint256 fee = rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, TICKET_REVENUE);

        assertEq(fee, expectedFee);

        IRips.ReferrerState memory stats = rips.exposed_referrerStats(referrer);
        assertEq(stats.currMonthVolume, TICKET_REVENUE);
        assertEq(stats.customFeePercent, CUSTOM_FEE);
    }

    function test_WhenNoReferralTiersAreConfiguredAndDefaultFeeIsZero() external {
        // it should return zero.
        // it should update only currMonthVolume.
        // it should emit a {ReferralStatsUpdated} event.
        vm.expectEmit();
        emit ReferralStatsUpdated(
            referrer,
            IRips.ReferrerState({
                activeFeePercent: 0,
                customFeePercent: 0,
                monthStartTimestamp: 0,
                currMonthVolume: TICKET_REVENUE
            })
        );

        uint256 fee = rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, TICKET_REVENUE);

        assertEq(fee, 0);

        IRips.ReferrerState memory stats = rips.exposed_referrerStats(referrer);
        assertEq(stats.currMonthVolume, TICKET_REVENUE);
        assertEq(stats.activeFeePercent, 0);
    }

    function test_WhenDefaultFeeIsSetAndReferrerHasNoPriorActivity() external {
        // it should return fee based on default fee percent.
        // it should update only currMonthVolume.
        // it should emit a {ReferralStatsUpdated} event.
        _setDefaultFee(DEFAULT_FEE);

        uint256 expectedFee = (PROTOCOL_FEE * DEFAULT_FEE) / rips.FEE_BASE();

        vm.expectEmit();
        emit ReferralStatsUpdated(
            referrer,
            IRips.ReferrerState({
                activeFeePercent: 0,
                customFeePercent: 0,
                monthStartTimestamp: 0,
                currMonthVolume: TICKET_REVENUE
            })
        );

        uint256 fee = rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, TICKET_REVENUE);

        assertEq(fee, expectedFee);

        IRips.ReferrerState memory stats = rips.exposed_referrerStats(referrer);
        assertEq(stats.currMonthVolume, TICKET_REVENUE);
        assertEq(stats.activeFeePercent, 0);
    }

    function test_WhenReferrerCurrentPeriodVolumeCrossesATierThreshold() external {
        // it should return fee based on default fee percent.
        // it should update only currMonthVolume.
        // it should emit a {ReferralStatsUpdated} event.
        _setDefaultFee(DEFAULT_FEE);
        _setTiers();

        // push referrer's current period volume above the low tier threshold
        uint256 volumeAboveTier = uint256(TIER_LOW_MIN_VOLUME) + 1 ether;

        uint256 expectedFee = (PROTOCOL_FEE * DEFAULT_FEE) / rips.FEE_BASE();

        vm.expectEmit();
        emit ReferralStatsUpdated(
            referrer,
            IRips.ReferrerState({
                activeFeePercent: 0,
                customFeePercent: 0,
                monthStartTimestamp: 0,
                currMonthVolume: volumeAboveTier
            })
        );

        uint256 fee = rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, volumeAboveTier);

        assertEq(fee, expectedFee);

        IRips.ReferrerState memory stats = rips.exposed_referrerStats(referrer);
        assertEq(stats.currMonthVolume, volumeAboveTier);
        // active fee is not updated mid-period; tier is only applied next period
        assertEq(stats.activeFeePercent, 0);
    }

    function test_WhenReferrersPreviousPeriodVolumeReachedATierThreshold() external {
        // it should return fee based on active fee percent.
        // it should update referrerStats.
        // it should emit a {ReferralStatsUpdated} event.
        _setDefaultFee(DEFAULT_FEE);
        _setTiers();

        // cross high tier threshold in period 1 (TIER_HIGH_FEE 10% > DEFAULT_FEE 5%)
        uint256 volumeAboveHighTier = uint256(TIER_HIGH_MIN_VOLUME) + 1 ether;
        rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, volumeAboveHighTier);

        _advanceToNextPeriod();

        // period 2: previous period volume unlocks high tier fee
        uint256 expectedFee = (PROTOCOL_FEE * TIER_HIGH_FEE) / rips.FEE_BASE();

        vm.expectEmit();
        emit ReferralStatsUpdated(
            referrer,
            IRips.ReferrerState({
                activeFeePercent: TIER_HIGH_FEE,
                customFeePercent: 0,
                monthStartTimestamp: uint40(rips.REFERRAL_PERIOD()),
                currMonthVolume: TICKET_REVENUE
            })
        );

        uint256 fee = rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, TICKET_REVENUE);

        assertEq(fee, expectedFee);

        IRips.ReferrerState memory stats = rips.exposed_referrerStats(referrer);
        assertEq(stats.activeFeePercent, TIER_HIGH_FEE);
    }

    function test_WhenActiveFeePercentIsBelowDefaultFeePercent() external {
        // it should return fee based on default fee percent.
        // it should update only currMonthVolume.
        // it should emit a {ReferralStatsUpdated} event.

        // TIER_LOW_FEE (3%) < DEFAULT_FEE (5%), so default should win
        _setDefaultFee(DEFAULT_FEE);
        _setTiers();

        // cross low tier threshold in period 1
        uint256 volumeAboveTier = uint256(TIER_LOW_MIN_VOLUME) + 1 ether;
        rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, volumeAboveTier);

        _advanceToNextPeriod();

        // period 2: active fee (3%) is below default (5%), default wins
        uint256 expectedFee = (PROTOCOL_FEE * DEFAULT_FEE) / rips.FEE_BASE();

        vm.expectEmit();
        emit ReferralStatsUpdated(
            referrer,
            IRips.ReferrerState({
                activeFeePercent: TIER_LOW_FEE,
                customFeePercent: 0,
                monthStartTimestamp: uint40(rips.REFERRAL_PERIOD()),
                currMonthVolume: TICKET_REVENUE
            })
        );

        uint256 fee = rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, TICKET_REVENUE);

        assertEq(fee, expectedFee);
    }

    function test_WhenANewPeriodStartsAfterAConsecutiveActivePeriod() external {
        // it should update referrerStats.
        // it should emit a {ReferralStatsUpdated} event.
        _setDefaultFee(DEFAULT_FEE);
        _setTiers();

        // period 1: cross tier threshold
        uint256 volumeAboveTier = uint256(TIER_LOW_MIN_VOLUME) + 1 ether;
        rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, volumeAboveTier);

        _advanceToNextPeriod();

        // period 2: active, cross tier threshold again
        rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, volumeAboveTier);

        IRips.ReferrerState memory statsAfterPeriod2 = rips.exposed_referrerStats(referrer);
        assertEq(statsAfterPeriod2.activeFeePercent, TIER_LOW_FEE);
        assertEq(statsAfterPeriod2.currMonthVolume, volumeAboveTier);

        _advanceToNextPeriod();

        // period 3: new period starts, stats should roll over correctly
        uint40 referralPeriod = uint40(rips.REFERRAL_PERIOD());
        vm.expectEmit();
        emit ReferralStatsUpdated(
            referrer,
            IRips.ReferrerState({
                activeFeePercent: TIER_LOW_FEE,
                customFeePercent: 0,
                monthStartTimestamp: 2 * referralPeriod,
                currMonthVolume: TICKET_REVENUE
            })
        );

        rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, TICKET_REVENUE);

        IRips.ReferrerState memory statsAfterPeriod3 = rips.exposed_referrerStats(referrer);
        assertEq(statsAfterPeriod3.activeFeePercent, TIER_LOW_FEE);
        assertEq(statsAfterPeriod3.currMonthVolume, TICKET_REVENUE);
    }

    function test_WhenANewPeriodStartsAfterAnInactivePeriodGap() external {
        // it should update referrerStats.
        // it should reset active fee percent to zero.
        // it should emit a {ReferralStatsUpdated} event.
        _setDefaultFee(DEFAULT_FEE);
        _setTiers();

        // period 1: cross tier threshold
        uint256 volumeAboveTier = uint256(TIER_LOW_MIN_VOLUME) + 1 ether;
        rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, volumeAboveTier);

        _advanceToNextPeriod();

        // period 2: active — unlocks tier fee, but skip period 3
        rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, volumeAboveTier);

        // skip two full periods (gap — period 3 is inactive)
        vm.warp(block.timestamp + 2 * rips.REFERRAL_PERIOD() + 1);

        // period 4: gap means active fee resets to zero
        uint40 referralPeriod = uint40(rips.REFERRAL_PERIOD());
        vm.expectEmit();
        emit ReferralStatsUpdated(
            referrer,
            IRips.ReferrerState({
                activeFeePercent: 0,
                customFeePercent: 0,
                monthStartTimestamp: 3 * referralPeriod,
                currMonthVolume: TICKET_REVENUE
            })
        );

        rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, TICKET_REVENUE);

        IRips.ReferrerState memory stats = rips.exposed_referrerStats(referrer);
        assertEq(stats.activeFeePercent, 0);
        assertEq(stats.currMonthVolume, TICKET_REVENUE);
        assertEq(stats.monthStartTimestamp, 3 * referralPeriod);
    }

    function test_WhenTwoReferrersHaveIndependentPeriodTracking() external {
        // it should apply tier fee to referrer A after their period ends.
        // it should apply default fee to referrer B whose period has not yet ended.
        // it should emit a {ReferralStatsUpdated} event for each referrer.
        _setDefaultFee(DEFAULT_FEE);
        _setTiers();

        uint256 volumeAboveHighTier = uint256(TIER_HIGH_MIN_VOLUME) + 1 ether;
        uint40 referralPeriod = uint40(rips.REFERRAL_PERIOD());

        // referrer A claims in period 1 with high volume
        rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, volumeAboveHighTier);

        _advanceToNextPeriod();

        // referrer B makes their first claim at the start of referrer A's period 2
        rips.exposed_collectReferrerFee(referrerB, PROTOCOL_FEE, volumeAboveHighTier);

        // referrer A: period 2 — previous period volume unlocks TIER_HIGH_FEE
        vm.expectEmit();
        emit ReferralStatsUpdated(
            referrer,
            IRips.ReferrerState({
                activeFeePercent: TIER_HIGH_FEE,
                customFeePercent: 0,
                monthStartTimestamp: referralPeriod,
                currMonthVolume: TICKET_REVENUE
            })
        );

        uint256 feeA = rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, TICKET_REVENUE);
        assertEq(feeA, (PROTOCOL_FEE * TIER_HIGH_FEE) / rips.FEE_BASE());

        IRips.ReferrerState memory statsA = rips.exposed_referrerStats(referrer);
        assertEq(statsA.activeFeePercent, TIER_HIGH_FEE);

        // referrer B: still in their first period — no previous period volume yet, default fee applies
        vm.expectEmit();
        emit ReferralStatsUpdated(
            referrerB,
            IRips.ReferrerState({
                activeFeePercent: 0,
                customFeePercent: 0,
                monthStartTimestamp: referralPeriod,
                currMonthVolume: volumeAboveHighTier + TICKET_REVENUE
            })
        );

        uint256 feeB = rips.exposed_collectReferrerFee(referrerB, PROTOCOL_FEE, TICKET_REVENUE);
        assertEq(feeB, (PROTOCOL_FEE * DEFAULT_FEE) / rips.FEE_BASE());

        IRips.ReferrerState memory statsB = rips.exposed_referrerStats(referrerB);
        assertEq(statsB.activeFeePercent, 0);
    }
}
