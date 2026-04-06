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

    function test_RevertWhen_TicketCapIsNotAPowerOfTwo() external whenTheCallerIsTheOwner {
        vm.expectRevert(IRips.TicketCapNotPowerOfTwo.selector);
        rips.createStake(configWithNonPowerOfTwoTicketCap());
    }

    function test_RevertWhen_TiersIsEmpty() external whenTheCallerIsTheOwner {
        vm.expectRevert(IRips.InvalidTierCount.selector);
        rips.createStake(configWithInvalidTierCount());
    }

    function test_RevertWhen_TiersExceedsMaxTierCount() external whenTheCallerIsTheOwner {
        vm.expectRevert(IRips.InvalidTierCount.selector);
        rips.createStake(configWithTierCountExceedsMax());
    }

    function test_RevertWhen_ATierHasMinPrizeGreaterThanMaxPrize()
        external
        whenTheCallerIsTheOwner
    {
        vm.expectRevert(IRips.InvalidPrizeRange.selector);
        rips.createStake(configWithMinPrizeGreaterThanMaxPrize());
    }

    function test_RevertWhen_TiersAreNotSortedByCountDescending() external whenTheCallerIsTheOwner {
        vm.expectRevert(IRips.TiersNotSortedByCount.selector);
        rips.createStake(configWithTiersNotSortedByCount());
    }

    function test_RevertWhen_TotalPrizeCountDoesNotEqualTicketCap()
        external
        whenTheCallerIsTheOwner
    {
        vm.expectRevert(IRips.PrizeCountMismatch.selector);
        rips.createStake(configWithPrizeCountMismatch());
    }

    function test_RevertWhen_TotalPrizePoolDoesNotEqualTicketCapTimesTicketCost()
        external
        whenTheCallerIsTheOwner
    {
        vm.expectRevert(IRips.PrizePoolMismatch.selector);
        rips.createStake(configWithPrizePoolMismatch());
    }

    function test_RevertWhen_FeePercentExceedsFEE_BASE() external whenTheCallerIsTheOwner {
        vm.expectRevert(IRips.FeeTooHigh.selector);
        rips.createStake(configWithFeeTooHigh());
    }

    function test_WhenFeePercentIsAtMostFEE_BASE() external whenTheCallerIsTheOwner {
        // it should store the stake configuration.
        // it should increment the next stake ID.
        // it should emit a {StakeCreated} event.
        uint256 expectedStakeId = rips.exposed_nextStakeId();
        uint256 expectedConfigId = rips.exposed_nextConfigId();

        vm.expectEmit();
        emit IRips.StakeCreated(expectedStakeId, expectedConfigId);

        uint256 stakeId = rips.createStake(validConfig());

        assertEq(stakeId, expectedStakeId);
        assertEq(rips.exposed_nextStakeId(), expectedStakeId + 1);

        uint256 configId = rips.stakeIdToCurrentConfigId(stakeId);
        assertNotEq(configId, 0);

        IRips.Config memory config = rips.exposed_config(configId);
        assertEq(config.ticketCap, DEFAULT_TICKET_CAP);
        assertEq(config.ticketCost, DEFAULT_TICKET_COST);
        assertEq(config.feePercent, DEFAULT_FEE_PERCENT);
    }
}
