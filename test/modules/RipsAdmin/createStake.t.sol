// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./StakeValidationSetup.sol";

contract Rips_CreateStake is StakeValidationSetup {
    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        vm.prank(user);
        vm.expectRevert();
        rips.createStake(validConfig());
    }

    modifier whenTheCallerIsTheOwner() {
        vm.startPrank(owner);
        _;
        vm.stopPrank();
    }

    function test_RevertWhen_EntryCapIsNotAPowerOfTwo() external whenTheCallerIsTheOwner {
        vm.expectRevert(IRips.EntryCapNotPowerOfTwo.selector);
        rips.createStake(configWithNonPowerOfTwoEntryCap());
    }

    function test_RevertWhen_TiersIsEmpty() external whenTheCallerIsTheOwner {
        vm.expectRevert(IRips.InvalidTierCount.selector);
        rips.createStake(configWithInvalidTierCount());
    }

    function test_RevertWhen_TiersExceedsMaxTierCount() external whenTheCallerIsTheOwner {
        vm.expectRevert(IRips.InvalidTierCount.selector);
        rips.createStake(configWithTierCountExceedsMax());
    }

    function test_RevertWhen_ATierHasMinPayoutGreaterThanMaxPayout()
        external
        whenTheCallerIsTheOwner
    {
        vm.expectRevert(IRips.InvalidPayoutRange.selector);
        rips.createStake(configWithMinPayoutGreaterThanMaxPayout());
    }

    function test_RevertWhen_TiersAreNotSortedByCountDescending() external whenTheCallerIsTheOwner {
        vm.expectRevert(IRips.TiersNotSortedByPayoutCount.selector);
        rips.createStake(configWithTiersNotSortedByPayoutCount());
    }

    function test_RevertWhen_TotalPayoutCountDoesNotEqualEntryCap()
        external
        whenTheCallerIsTheOwner
    {
        vm.expectRevert(IRips.PayoutCountMismatch.selector);
        rips.createStake(configWithPayoutCountMismatch());
    }

    function test_RevertWhen_TotalPayoutPoolDoesNotEqualEntryCapTimesEntryPrice()
        external
        whenTheCallerIsTheOwner
    {
        vm.expectRevert(IRips.PayoutPoolMismatch.selector);
        rips.createStake(configWithPayoutPoolMismatch());
    }

    function test_RevertWhen_FeePercentExceedsFEE_BASE() external whenTheCallerIsTheOwner {
        vm.expectRevert(IRips.FeeTooHigh.selector);
        rips.createStake(configWithFeeTooHigh());
    }

    function test_WhenFeePercentIsAtMostFEE_BASE() external whenTheCallerIsTheOwner {
        // it should store the stake configuration.
        // it should increment the next stake ID.
        // it should emit a {StakeCreated} event.
        uint64 expectedStakeId = rips.exposed_nextStakeId();
        uint64 expectedConfigId = rips.exposed_nextConfigId();

        vm.expectEmit();
        emit IRips.StakeCreated(expectedStakeId, expectedConfigId);

        uint64 stakeId = rips.createStake(validConfig());

        assertEq(stakeId, expectedStakeId);
        assertEq(rips.exposed_nextStakeId(), expectedStakeId + 1);

        uint64 configId = rips.stakeIdToCurrentConfigId(stakeId);
        assertNotEq(configId, 0);

        IRips.Config memory config = rips.exposed_config(configId);
        assertEq(config.entryCap, DEFAULT_ENTRY_CAP);
        assertEq(config.entryPrice, DEFAULT_ENTRY_PRICE);
        assertEq(config.feePercent, DEFAULT_FEE_PERCENT);
    }
}
