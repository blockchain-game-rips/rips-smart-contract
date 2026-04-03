// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract RipsReferral_CollectReferrerFee is RipsTestBase {
    uint256 private constant PROTOCOL_FEE = 1 ether;
    uint256 private constant TICKET_REVENUE = 10 ether;
    uint16 private constant DEFAULT_REFERRAL_FEE = 300;
    uint16 private constant TIER_1_FEE_PERCENT = 800;
    uint16 private constant TIER_2_FEE_PERCENT = 1500;
    uint16 private constant CUSTOM_FEE_PERCENT = 2000;
    uint128 private constant TIER_1_MIN_VOLUME = 5 ether;
    uint128 private constant TIER_2_MIN_VOLUME = 20 ether;

    function _setDefaultReferralFee() private {
        vm.prank(owner);
        rips.setDefaultReferralFee(DEFAULT_REFERRAL_FEE);
    }

    function _setTiers() private {
        IRips.ReferralTier[] memory tiers = new IRips.ReferralTier[](2);
        tiers[0] =
            IRips.ReferralTier({minVolume: TIER_1_MIN_VOLUME, feePercent: TIER_1_FEE_PERCENT});
        tiers[1] =
            IRips.ReferralTier({minVolume: TIER_2_MIN_VOLUME, feePercent: TIER_2_FEE_PERCENT});

        vm.prank(owner);
        rips.setReferralTiers(tiers);
    }

    function _collect(address ref, uint256 protocolFee, uint256 revenue) private returns (uint256) {
        return rips.exposed_collectReferrerFee(ref, protocolFee, revenue);
    }

    function test_WhenReferrerIsZeroAddress() external {
        uint256 fee = _collect(address(0), PROTOCOL_FEE, TICKET_REVENUE);
        assertEq(fee, 0);
    }

    function test_WhenReferrerHasACustomFeeSet() external {
        vm.prank(owner);
        rips.setReferrerCustomFee(referrer, CUSTOM_FEE_PERCENT);

        uint256 fee = _collect(referrer, PROTOCOL_FEE, TICKET_REVENUE);

        assertEq(fee, 0.2 ether);

        IRips.ReferrerStats memory stats = rips.exposed_referrerStats(referrer);
        assertEq(stats.currMonthVolume, 0);
    }

    function test_WhenNoReferralTiersAreConfiguredAndBaseFeeIsZero() external {
        uint256 fee = _collect(referrer, PROTOCOL_FEE, TICKET_REVENUE);
        assertEq(fee, 0);
    }

    function test_WhenBaseFeeIsSetAndReferrerHasNoPriorActivity() external {
        _setDefaultReferralFee();

        uint256 fee = _collect(referrer, PROTOCOL_FEE, TICKET_REVENUE);

        assertEq(fee, 0.03 ether);

        IRips.ReferrerStats memory stats = rips.exposed_referrerStats(referrer);
        assertEq(stats.currMonthVolume, TICKET_REVENUE);
    }

    function test_WhenReferrerCurrentMonthVolumeCrossesATierThreshold() external {
        _setDefaultReferralFee();
        _setTiers();

        vm.expectEmit();
        emit IRips.ReferrerStatsUpdated(referrer, 0, TIER_1_FEE_PERCENT);

        _collect(referrer, PROTOCOL_FEE, TIER_1_MIN_VOLUME);

        IRips.ReferrerStats memory stats = rips.exposed_referrerStats(referrer);
        assertEq(stats.nextFeePercent, TIER_1_FEE_PERCENT);
    }

    function test_WhenReferrerCurrentMonthVolumeCrossesMultipleTierThresholds() external {
        _setDefaultReferralFee();
        _setTiers();

        _collect(referrer, PROTOCOL_FEE, TIER_2_MIN_VOLUME);

        IRips.ReferrerStats memory stats = rips.exposed_referrerStats(referrer);
        assertEq(stats.nextFeePercent, TIER_2_FEE_PERCENT);
    }

    function test_WhenReferrersPreviousMonthVolumeReachedATierThreshold() external {
        _setDefaultReferralFee();
        _setTiers();

        _collect(referrer, PROTOCOL_FEE, TIER_1_MIN_VOLUME);

        vm.warp(block.timestamp + 31 days);

        uint256 fee = _collect(referrer, PROTOCOL_FEE, TICKET_REVENUE);

        assertEq(fee, 0.08 ether);
    }

    function test_WhenActiveFeePercentIsBelowDefaultReferralFee() external {
        _setDefaultReferralFee();
        _setTiers();

        vm.warp(block.timestamp + 31 days);

        uint256 fee = _collect(referrer, PROTOCOL_FEE, TICKET_REVENUE);

        assertEq(fee, 0.03 ether);
    }

    function test_WhenANewMonthStartsAfterAConsecutiveActiveMonth() external {
        _setDefaultReferralFee();
        _setTiers();

        _collect(referrer, PROTOCOL_FEE, TIER_1_MIN_VOLUME);

        vm.warp(block.timestamp + 31 days);

        _collect(referrer, PROTOCOL_FEE, TICKET_REVENUE);

        IRips.ReferrerStats memory stats = rips.exposed_referrerStats(referrer);
        assertEq(stats.activeFeePercent, TIER_1_FEE_PERCENT);
        assertEq(stats.currMonthVolume, TICKET_REVENUE);
    }

    function test_WhenANewMonthStartsAfterAnInactiveMonthGap() external {
        _setDefaultReferralFee();
        _setTiers();

        _collect(referrer, PROTOCOL_FEE, TIER_1_MIN_VOLUME);

        vm.warp(block.timestamp + 62 days);

        _collect(referrer, PROTOCOL_FEE, TICKET_REVENUE);

        IRips.ReferrerStats memory stats = rips.exposed_referrerStats(referrer);
        assertEq(stats.activeFeePercent, 0);
        assertEq(stats.currMonthVolume, TICKET_REVENUE);
    }
}
