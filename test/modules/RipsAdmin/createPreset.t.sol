// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./PresetValidationSetup.sol";

contract Rips_CreatePreset is PresetValidationSetup {
    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        vm.prank(user);
        vm.expectRevert();
        rips.createPreset(validConfig());
    }

    modifier whenTheCallerIsTheOwner() {
        vm.startPrank(owner);
        _;
        vm.stopPrank();
    }

    function test_RevertWhen_EntryCapIsNotAPowerOfTwo() external whenTheCallerIsTheOwner {
        vm.expectRevert(IRips.EntryCapNotPowerOfTwo.selector);
        rips.createPreset(configWithNonPowerOfTwoEntryCap());
    }

    function test_RevertWhen_EntryPriceIsBelowTheMinimum() external whenTheCallerIsTheOwner {
        IRips.Config memory config = configWithEntryPriceBelowMinimum();

        vm.expectRevert(IRips.EntryPriceTooLow.selector);
        rips.createPreset(config);
    }

    function test_RevertWhen_TiersIsEmpty() external whenTheCallerIsTheOwner {
        vm.expectRevert(IRips.InvalidTierCount.selector);
        rips.createPreset(configWithInvalidTierCount());
    }

    function test_RevertWhen_TiersExceedsMaxTierCount() external whenTheCallerIsTheOwner {
        IRips.Config memory config = configWithTierCountExceedsMax();

        vm.expectRevert(IRips.InvalidTierCount.selector);
        rips.createPreset(config);
    }

    function test_RevertWhen_ATierHasMinPayoutGreaterThanMaxPayout() external whenTheCallerIsTheOwner {
        vm.expectRevert(IRips.InvalidPayoutRange.selector);
        rips.createPreset(configWithMinPayoutGreaterThanMaxPayout());
    }

    function test_RevertWhen_TiersAreNotSortedByCountDescending() external whenTheCallerIsTheOwner {
        vm.expectRevert(IRips.TiersNotSortedByPayoutCount.selector);
        rips.createPreset(configWithTiersNotSortedByPayoutCount());
    }

    function test_RevertWhen_ATierHasAZeroPayoutCount() external whenTheCallerIsTheOwner {
        vm.expectRevert(IRips.InvalidPayoutCount.selector);
        rips.createPreset(configWithZeroPayoutCountTier());
    }

    function test_RevertWhen_TotalPayoutCountDoesNotEqualEntryCap() external whenTheCallerIsTheOwner {
        vm.expectRevert(IRips.InvalidPayoutCount.selector);
        rips.createPreset(configWithPayoutCountMismatch());
    }

    function test_RevertWhen_TotalPayoutPoolDoesNotEqualEntryCapTimesEntryPrice() external whenTheCallerIsTheOwner {
        vm.expectRevert(IRips.PayoutPoolMismatch.selector);
        rips.createPreset(configWithPayoutPoolMismatch());
    }

    function test_RevertWhen_FeePercentExceedsFEE_BASE() external whenTheCallerIsTheOwner {
        vm.expectRevert(IRips.FeeTooHigh.selector);
        rips.createPreset(configWithFeeTooHigh());
    }

    function test_WhenFeePercentIsAtMostFEE_BASE() external whenTheCallerIsTheOwner {
        // it should store the preset configuration.
        // it should increment the next preset ID.
        // it should emit a {PresetCreated} event.
        uint64 expectedPresetId = rips.exposed_nextPresetId();
        uint64 expectedConfigId = rips.exposed_nextConfigId();

        vm.expectEmit();
        emit IRips.PresetCreated(expectedPresetId, expectedConfigId);

        uint64 presetId = rips.createPreset(validConfig());

        assertEq(presetId, expectedPresetId);
        assertEq(rips.exposed_nextPresetId(), expectedPresetId + 1);

        uint64 configId = rips.presetIdToCurrentConfigId(presetId);
        assertNotEq(configId, 0);

        IRips.Config memory config = rips.exposed_config(configId);
        assertEq(config.entryCap, DEFAULT_ENTRY_CAP);
        assertEq(config.entryPrice, DEFAULT_ENTRY_PRICE);
        assertEq(config.feeBps, DEFAULT_FEE_PERCENT);
    }
}
