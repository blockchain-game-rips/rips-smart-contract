// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract RipsReferral_CollectReferrerFee is RipsTestBase {
    uint256 internal constant PROTOCOL_FEE = 1 ether;
    uint256 internal constant TICKET_REVENUE = 10 ether;

    uint16 internal constant DEFAULT_FEE = 500; // 5%
    uint16 internal constant TIER_LOW_FEE = 300; // 3%
    uint16 internal constant TIER_HIGH_FEE = 1000; // 10%
    uint16 internal constant CUSTOM_FEE = 800; // 8%

    uint128 internal constant TIER_LOW_MIN_VOLUME = 5 ether;
    uint128 internal constant TIER_HIGH_MIN_VOLUME = 50 ether;

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

    function _advanceToNextMonth() internal {
        vm.warp(block.timestamp + 31 days);
    }

    function test_WhenReferrerIsZeroAddress() external {
        // it should return zero.
        uint256 fee = rips.exposed_collectReferrerFee(address(0), PROTOCOL_FEE, TICKET_REVENUE);

        assertEq(fee, 0);
    }

    function test_WhenReferrerHasACustomFeeSet() external {
        // it should return fee based on custom fee percent.
        // it should update only currMonthVolume.
        _setCustomFee(referrer, CUSTOM_FEE);

        uint256 expectedFee = (PROTOCOL_FEE * CUSTOM_FEE) / rips.FEE_BASE();

        uint256 fee = rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, TICKET_REVENUE);

        assertEq(fee, expectedFee);

        IRips.ReferrerStats memory stats = rips.exposed_referrerStats(referrer);
        assertEq(stats.currMonthVolume, TICKET_REVENUE);
        assertEq(stats.customFeePercent, CUSTOM_FEE);
    }

    function test_WhenNoReferralTiersAreConfiguredAndDefaultFeeIsZero() external {
        // it should return zero.
        // it should update only currMonthVolume.
        uint256 fee = rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, TICKET_REVENUE);

        assertEq(fee, 0);

        IRips.ReferrerStats memory stats = rips.exposed_referrerStats(referrer);
        assertEq(stats.currMonthVolume, TICKET_REVENUE);
        assertEq(stats.activeFeePercent, 0);
    }

    function test_WhenDefaultFeeIsSetAndReferrerHasNoPriorActivity() external {
        // it should return fee based on default fee percent.
        // it should update only currMonthVolume.
        _setDefaultFee(DEFAULT_FEE);

        uint256 expectedFee = (PROTOCOL_FEE * DEFAULT_FEE) / rips.FEE_BASE();

        uint256 fee = rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, TICKET_REVENUE);

        assertEq(fee, expectedFee);

        IRips.ReferrerStats memory stats = rips.exposed_referrerStats(referrer);
        assertEq(stats.currMonthVolume, TICKET_REVENUE);
        assertEq(stats.activeFeePercent, 0);
    }

    function test_WhenReferrerCurrentMonthVolumeCrossesATierThreshold() external {
        // it should return fee based on default fee percent.
        // it should update only currMonthVolume.
        _setDefaultFee(DEFAULT_FEE);
        _setTiers();

        // push referrer's current month volume above the low tier threshold
        uint256 volumeAboveTier = uint256(TIER_LOW_MIN_VOLUME) + 1 ether;

        uint256 expectedFee = (PROTOCOL_FEE * DEFAULT_FEE) / rips.FEE_BASE();

        uint256 fee = rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, volumeAboveTier);

        assertEq(fee, expectedFee);

        IRips.ReferrerStats memory stats = rips.exposed_referrerStats(referrer);
        assertEq(stats.currMonthVolume, volumeAboveTier);
        // active fee is not updated mid-month; tier is only applied next month
        assertEq(stats.activeFeePercent, 0);
    }

    function test_WhenReferrersPreviousMonthVolumeReachedATierThreshold() external {
        // it should return fee based on active fee percent.
        // it should update referrerStats.
        _setDefaultFee(DEFAULT_FEE);
        _setTiers();

        // cross tier threshold in month 1
        uint256 volumeAboveTier = uint256(TIER_LOW_MIN_VOLUME) + 1 ether;
        rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, volumeAboveTier);

        _advanceToNextMonth();

        // month 2: previous month volume unlocks tier fee
        uint256 expectedFee = (PROTOCOL_FEE * TIER_LOW_FEE) / rips.FEE_BASE();

        uint256 fee = rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, TICKET_REVENUE);

        assertEq(fee, expectedFee);

        IRips.ReferrerStats memory stats = rips.exposed_referrerStats(referrer);
        assertEq(stats.activeFeePercent, TIER_LOW_FEE);
    }

    function test_WhenActiveFeePercentIsBelowDefaultFeePercent() external {
        // it should return fee based on default fee percent.
        // it should update only currMonthVolume.

        // TIER_LOW_FEE (3%) < DEFAULT_FEE (5%), so default should win
        _setDefaultFee(DEFAULT_FEE);
        _setTiers();

        // cross low tier threshold in month 1
        uint256 volumeAboveTier = uint256(TIER_LOW_MIN_VOLUME) + 1 ether;
        rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, volumeAboveTier);

        _advanceToNextMonth();

        // month 2: active fee (3%) is below default (5%), default wins
        uint256 expectedFee = (PROTOCOL_FEE * DEFAULT_FEE) / rips.FEE_BASE();

        uint256 fee = rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, TICKET_REVENUE);

        assertEq(fee, expectedFee);
    }

    function test_WhenANewMonthStartsAfterAConsecutiveActiveMonth() external {
        // it should update referrerStats.
        _setDefaultFee(DEFAULT_FEE);
        _setTiers();

        // month 1: cross tier threshold
        uint256 volumeAboveTier = uint256(TIER_LOW_MIN_VOLUME) + 1 ether;
        rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, volumeAboveTier);

        _advanceToNextMonth();

        // month 2: active, cross tier threshold again
        rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, volumeAboveTier);

        IRips.ReferrerStats memory statsAfterMonth2 = rips.exposed_referrerStats(referrer);
        assertEq(statsAfterMonth2.activeFeePercent, TIER_LOW_FEE);
        assertEq(statsAfterMonth2.currMonthVolume, volumeAboveTier);

        _advanceToNextMonth();

        // month 3: new month starts, stats should roll over correctly
        rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, TICKET_REVENUE);

        IRips.ReferrerStats memory statsAfterMonth3 = rips.exposed_referrerStats(referrer);
        assertEq(statsAfterMonth3.activeFeePercent, TIER_LOW_FEE);
        assertEq(statsAfterMonth3.currMonthVolume, TICKET_REVENUE);
    }

    function test_WhenANewMonthStartsAfterAnInactiveMonthGap() external {
        // it should update referrerStats.
        // it should reset active fee percent to zero.
        _setDefaultFee(DEFAULT_FEE);
        _setTiers();

        // month 1: cross tier threshold
        uint256 volumeAboveTier = uint256(TIER_LOW_MIN_VOLUME) + 1 ether;
        rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, volumeAboveTier);

        _advanceToNextMonth();

        // month 2: active — unlocks tier fee for month 2, but skip month 3
        rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, volumeAboveTier);

        // skip two months (gap — month 3 is inactive)
        vm.warp(block.timestamp + 62 days);

        // month 4: gap means active fee resets to zero
        rips.exposed_collectReferrerFee(referrer, PROTOCOL_FEE, TICKET_REVENUE);

        IRips.ReferrerStats memory stats = rips.exposed_referrerStats(referrer);
        assertEq(stats.activeFeePercent, 0);
        assertEq(stats.currMonthVolume, TICKET_REVENUE);
    }
}
