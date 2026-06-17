// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./StakeValidationSetup.sol";

contract Rips_UpdateStake is StakeValidationSetup {
    uint64 private stakeId;

    function setUp() public override {
        super.setUp();

        stakeId = _createDefaultStake();
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
            feePercent: DEFAULT_FEE_PERCENT
        });
    }

    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        // it should revert.
        vm.prank(user);
        vm.expectRevert();
        rips.updateStake(stakeId, validConfig());
    }

    modifier whenTheCallerIsTheOwner() {
        vm.startPrank(owner);
        _;
        vm.stopPrank();
    }

    function test_RevertWhen_TheStakeDoesNotExist() external whenTheCallerIsTheOwner {
        // it should revert.
        vm.expectRevert(IRips.StakeNotExist.selector);
        rips.updateStake(999, validConfig());
    }

    function test_RevertWhen_TheStakeIsDeleted() external whenTheCallerIsTheOwner {
        // it should revert.
        rips.deleteStake(stakeId);

        vm.expectRevert(IRips.StakeNotExist.selector);
        rips.updateStake(stakeId, validConfig());
    }

    function test_RevertWhen_EntryCapIsNotAPowerOfTwo() external whenTheCallerIsTheOwner {
        // it should revert.
        vm.expectRevert(IRips.EntryCapNotPowerOfTwo.selector);
        rips.updateStake(stakeId, configWithNonPowerOfTwoEntryCap());
    }

    function test_RevertWhen_TiersIsEmpty() external whenTheCallerIsTheOwner {
        // it should revert.
        vm.expectRevert(IRips.InvalidTierCount.selector);
        rips.updateStake(stakeId, configWithInvalidTierCount());
    }

    function test_RevertWhen_TiersExceedsMaxTierCount() external whenTheCallerIsTheOwner {
        // it should revert.
        vm.expectRevert(IRips.InvalidTierCount.selector);
        rips.updateStake(stakeId, configWithTierCountExceedsMax());
    }

    function test_RevertWhen_ATierHasMinPayoutGreaterThanMaxPayout()
        external
        whenTheCallerIsTheOwner
    {
        // it should revert.
        vm.expectRevert(IRips.InvalidPayoutRange.selector);
        rips.updateStake(stakeId, configWithMinPayoutGreaterThanMaxPayout());
    }

    function test_RevertWhen_TiersAreNotSortedByCountDescending() external whenTheCallerIsTheOwner {
        // it should revert.
        vm.expectRevert(IRips.TiersNotSortedByPayoutCount.selector);
        rips.updateStake(stakeId, configWithTiersNotSortedByPayoutCount());
    }

    function test_RevertWhen_TotalPayoutCountDoesNotEqualEntryCap()
        external
        whenTheCallerIsTheOwner
    {
        // it should revert.
        vm.expectRevert(IRips.PayoutCountMismatch.selector);
        rips.updateStake(stakeId, configWithPayoutCountMismatch());
    }

    function test_RevertWhen_TotalPayoutPoolDoesNotEqualEntryCapTimesEntryPrice()
        external
        whenTheCallerIsTheOwner
    {
        // it should revert.
        vm.expectRevert(IRips.PayoutPoolMismatch.selector);
        rips.updateStake(stakeId, configWithPayoutPoolMismatch());
    }

    function test_RevertWhen_FeePercentExceedsFEE_BASE() external whenTheCallerIsTheOwner {
        // it should revert.
        vm.expectRevert(IRips.FeeTooHigh.selector);
        rips.updateStake(stakeId, configWithFeeTooHigh());
    }

    function test_WhenTheConfigIsValid() external whenTheCallerIsTheOwner {
        // it should update the config immediately.
        // it should emit a {StakeUpdated} event.
        IRips.Config memory config = _updatedConfig();
        uint64 expectedConfigId = rips.exposed_nextConfigId();

        vm.expectEmit();
        emit IRips.StakeUpdated(stakeId, expectedConfigId);

        rips.updateStake(stakeId, config);

        uint64 configId = rips.stakeIdToCurrentConfigId(stakeId);
        IRips.Config memory stored = rips.exposed_config(configId);
        assertEq(stored.entryCap, config.entryCap);
        assertEq(stored.entryPrice, config.entryPrice);
        assertEq(stored.currency, config.currency);
        assertEq(stored.duration, config.duration);
        assertEq(stored.tiers.length, config.tiers.length);
        assertEq(stored.feePercent, config.feePercent);
    }

    function test_WhenTheNextRipIsCreatedAfterAnUpdate() external whenTheCallerIsTheOwner {
        // it should use the new config for the new rip.
        IRips.Config memory config = _updatedConfig();

        rips.updateStake(stakeId, config);

        vm.stopPrank();

        vm.warp(block.timestamp + DEFAULT_DURATION + 1);

        vm.deal(user, 100 ether);
        vm.prank(user);
        rips.enterRip{value: config.entryPrice}(stakeId, 1, user);

        uint64 configId = rips.stakeIdToCurrentConfigId(stakeId);
        IRips.Config memory active = rips.exposed_config(configId);
        assertEq(active.entryCap, config.entryCap);
        assertEq(active.entryPrice, config.entryPrice);
        assertEq(active.currency, config.currency);
        assertEq(active.duration, config.duration);
    }
}
