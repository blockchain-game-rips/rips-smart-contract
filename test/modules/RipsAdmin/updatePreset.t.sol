// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./PresetValidationSetup.sol";

contract Rips_UpdatePreset is PresetValidationSetup {
    uint64 private presetId;

    function setUp() public override {
        super.setUp();

        presetId = _createDefaultPreset();
    }

    function _updatedConfig() private pure returns (IRips.Config memory) {
        uint64 newEntryCap = DEFAULT_ENTRY_CAP * 2;
        uint256 newEntryPrice = DEFAULT_ENTRY_PRICE * 2;

        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](1);
        tiers[0] = IRips.PayoutTier({
            payoutCount: newEntryCap,
            minPayout: uint128(newEntryPrice),
            maxPayout: uint128(newEntryPrice)
        });

        return IRips.Config({
            currency: address(0),
            tiers: tiers,
            entryCap: newEntryCap,
            duration: DEFAULT_DURATION,
            entryPrice: newEntryPrice,
            feeBps: DEFAULT_FEE_PERCENT
        });
    }

    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        // it should revert.
        vm.prank(user);
        vm.expectRevert();
        rips.updatePreset(presetId, validConfig());
    }

    modifier whenTheCallerIsTheOwner() {
        vm.startPrank(owner);
        _;
        vm.stopPrank();
    }

    function test_RevertWhen_ThePresetDoesNotExist() external whenTheCallerIsTheOwner {
        // it should revert.
        vm.expectRevert(IRips.PresetNotExist.selector);
        rips.updatePreset(999, validConfig());
    }

    function test_RevertWhen_ThePresetIsDeleted() external whenTheCallerIsTheOwner {
        // it should revert.
        rips.deletePreset(presetId);

        vm.expectRevert(IRips.PresetNotExist.selector);
        rips.updatePreset(presetId, validConfig());
    }

    function test_RevertWhen_EntryCapIsNotAPowerOfTwo() external whenTheCallerIsTheOwner {
        // it should revert.
        vm.expectRevert(IRips.EntryCapNotPowerOfTwo.selector);
        rips.updatePreset(presetId, configWithNonPowerOfTwoEntryCap());
    }

    function test_RevertWhen_TiersIsEmpty() external whenTheCallerIsTheOwner {
        // it should revert.
        vm.expectRevert(IRips.InvalidTierCount.selector);
        rips.updatePreset(presetId, configWithInvalidTierCount());
    }

    function test_RevertWhen_TiersExceedsMaxTierCount() external whenTheCallerIsTheOwner {
        // it should revert.
        vm.expectRevert(IRips.InvalidTierCount.selector);
        rips.updatePreset(presetId, configWithTierCountExceedsMax());
    }

    function test_RevertWhen_ATierHasMinPayoutGreaterThanMaxPayout()
        external
        whenTheCallerIsTheOwner
    {
        // it should revert.
        vm.expectRevert(IRips.InvalidPayoutRange.selector);
        rips.updatePreset(presetId, configWithMinPayoutGreaterThanMaxPayout());
    }

    function test_RevertWhen_TiersAreNotSortedByCountDescending() external whenTheCallerIsTheOwner {
        // it should revert.
        vm.expectRevert(IRips.TiersNotSortedByPayoutCount.selector);
        rips.updatePreset(presetId, configWithTiersNotSortedByPayoutCount());
    }

    function test_RevertWhen_TotalPayoutCountDoesNotEqualEntryCap()
        external
        whenTheCallerIsTheOwner
    {
        // it should revert.
        vm.expectRevert(IRips.PayoutCountMismatch.selector);
        rips.updatePreset(presetId, configWithPayoutCountMismatch());
    }

    function test_RevertWhen_TotalPayoutPoolDoesNotEqualEntryCapTimesEntryPrice()
        external
        whenTheCallerIsTheOwner
    {
        // it should revert.
        vm.expectRevert(IRips.PayoutPoolMismatch.selector);
        rips.updatePreset(presetId, configWithPayoutPoolMismatch());
    }

    function test_RevertWhen_FeePercentExceedsFEE_BASE() external whenTheCallerIsTheOwner {
        // it should revert.
        vm.expectRevert(IRips.FeeTooHigh.selector);
        rips.updatePreset(presetId, configWithFeeTooHigh());
    }

    function test_WhenTheConfigIsValid() external whenTheCallerIsTheOwner {
        // it should update the config immediately.
        // it should emit a {PresetUpdated} event.
        IRips.Config memory config = _updatedConfig();
        uint64 expectedConfigId = rips.exposed_nextConfigId();

        vm.expectEmit();
        emit IRips.PresetUpdated(presetId, expectedConfigId);

        rips.updatePreset(presetId, config);

        uint64 configId = rips.presetIdToCurrentConfigId(presetId);
        IRips.Config memory stored = rips.exposed_config(configId);
        assertEq(stored.entryCap, config.entryCap);
        assertEq(stored.entryPrice, config.entryPrice);
        assertEq(stored.currency, config.currency);
        assertEq(stored.duration, config.duration);
        assertEq(stored.tiers.length, config.tiers.length);
        assertEq(stored.feeBps, config.feeBps);
    }

    function test_WhenTheNextRipIsCreatedAfterAnUpdate() external whenTheCallerIsTheOwner {
        // it should use the new config for the new rip.
        IRips.Config memory config = _updatedConfig();

        rips.updatePreset(presetId, config);

        vm.stopPrank();

        vm.warp(block.timestamp + DEFAULT_DURATION + 1);

        vm.deal(user, 100 ether);
        vm.prank(user);
        rips.enterRip{value: config.entryPrice}(presetId, 1, user);

        uint64 configId = rips.presetIdToCurrentConfigId(presetId);
        IRips.Config memory active = rips.exposed_config(configId);
        assertEq(active.entryCap, config.entryCap);
        assertEq(active.entryPrice, config.entryPrice);
        assertEq(active.currency, config.currency);
        assertEq(active.duration, config.duration);
    }
}
