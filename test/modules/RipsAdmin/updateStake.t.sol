// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./StakeValidationSetup.sol";

contract Rips_UpdateStake is StakeValidationSetup {
    uint256 private stakeId;

    function setUp() public override {
        super.setUp();

        stakeId = _createDefaultStake();
    }

    function _updatedConfig() private pure returns (IRips.Config memory) {
        uint256 newTicketCap = DEFAULT_TICKET_CAP * 2;
        uint256 newTicketCost = DEFAULT_TICKET_COST * 2;

        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: uint64(newTicketCap),
            minPrize: uint128(newTicketCost),
            maxPrize: uint128(newTicketCost)
        });

        return IRips.Config({
            currency: address(0),
            prizeDistribution: tiers,
            ticketCap: newTicketCap,
            duration: DEFAULT_DURATION,
            ticketCost: newTicketCost,
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

    function test_RevertWhen_TicketCapIsNotAPowerOfTwo() external whenTheCallerIsTheOwner {
        // it should revert.
        vm.expectRevert(IRips.TicketCapNotPowerOfTwo.selector);
        rips.updateStake(stakeId, configWithNonPowerOfTwoTicketCap());
    }

    function test_RevertWhen_PrizeDistributionIsEmpty() external whenTheCallerIsTheOwner {
        // it should revert.
        vm.expectRevert(IRips.EmptyPrizeDistribution.selector);
        rips.updateStake(stakeId, configWithEmptyPrizeDistribution());
    }

    function test_RevertWhen_ATierHasMinPrizeGreaterThanMaxPrize()
        external
        whenTheCallerIsTheOwner
    {
        // it should revert.
        vm.expectRevert(IRips.InvalidPrizeRange.selector);
        rips.updateStake(stakeId, configWithMinPrizeGreaterThanMaxPrize());
    }

    function test_RevertWhen_TotalPrizeCountDoesNotEqualTicketCap()
        external
        whenTheCallerIsTheOwner
    {
        // it should revert.
        vm.expectRevert(IRips.PrizeCountMismatch.selector);
        rips.updateStake(stakeId, configWithPrizeCountMismatch());
    }

    function test_RevertWhen_TotalPrizePoolDoesNotEqualTicketCapTimesTicketCost()
        external
        whenTheCallerIsTheOwner
    {
        // it should revert.
        vm.expectRevert(IRips.PrizePoolMismatch.selector);
        rips.updateStake(stakeId, configWithPrizePoolMismatch());
    }

    function test_RevertWhen_FeePercentExceeds10000() external whenTheCallerIsTheOwner {
        // it should revert.
        vm.expectRevert(IRips.FeeTooHigh.selector);
        rips.updateStake(stakeId, configWithFeeTooHigh());
    }

    function test_WhenTheConfigIsValid() external whenTheCallerIsTheOwner {
        // it should update the config immediately.
        // it should emit a {StakeUpdated} event.
        IRips.Config memory config = _updatedConfig();

        vm.expectEmit();
        emit IRips.StakeUpdated(stakeId);

        rips.updateStake(stakeId, config);

        uint256 configId = rips.stakeIdToCurrentConfigId(stakeId);
        IRips.Config memory stored = rips.exposed_config(configId);
        assertEq(stored.ticketCap, config.ticketCap);
        assertEq(stored.ticketCost, config.ticketCost);
        assertEq(stored.currency, config.currency);
        assertEq(stored.duration, config.duration);
        assertEq(stored.prizeDistribution.length, config.prizeDistribution.length);
        assertEq(stored.feePercent, config.feePercent);
    }

    function test_WhenTheNextRoundIsCreatedAfterAnUpdate() external whenTheCallerIsTheOwner {
        // it should use the new config for the new round.
        IRips.Config memory config = _updatedConfig();

        rips.updateStake(stakeId, config);

        vm.stopPrank();

        vm.warp(block.timestamp + DEFAULT_DURATION + 1);

        vm.deal(user, 100 ether);
        vm.prank(user);
        rips.buyTickets{value: config.ticketCost}(stakeId, 1, user);

        uint256 configId = rips.stakeIdToCurrentConfigId(stakeId);
        IRips.Config memory active = rips.exposed_config(configId);
        assertEq(active.ticketCap, config.ticketCap);
        assertEq(active.ticketCost, config.ticketCost);
        assertEq(active.currency, config.currency);
        assertEq(active.duration, config.duration);
    }
}
