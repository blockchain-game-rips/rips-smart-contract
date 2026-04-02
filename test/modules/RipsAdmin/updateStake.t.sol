// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract Rips_UpdateStake is RipsTestBase {
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
        rips.updateStake(stakeId, _updatedConfig());
    }

    modifier whenTheCallerIsTheOwner() {
        vm.startPrank(owner);
        _;
        vm.stopPrank();
    }

    function test_RevertWhen_TheStakeDoesNotExist() external whenTheCallerIsTheOwner {
        // it should revert.
        uint256 nonExistentStakeId = 999;

        vm.expectRevert(IRips.StakeNotExist.selector);
        rips.updateStake(nonExistentStakeId, _updatedConfig());
    }

    function test_RevertWhen_TicketCapIsNotAPowerOfTwo() external whenTheCallerIsTheOwner {
        // it should revert.
        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: 3,
            minPrize: uint128(DEFAULT_TICKET_COST),
            maxPrize: uint128(DEFAULT_TICKET_COST)
        });

        vm.expectRevert(IRips.TicketCapNotPowerOfTwo.selector);
        rips.updateStake(
            stakeId,
            IRips.Config({
                currency: address(0),
                prizeDistribution: tiers,
                ticketCap: 3,
                duration: DEFAULT_DURATION,
                ticketCost: DEFAULT_TICKET_COST,
                feePercent: DEFAULT_FEE_PERCENT
            })
        );
    }

    function test_RevertWhen_PrizeDistributionIsEmpty() external whenTheCallerIsTheOwner {
        // it should revert.
        IRips.PrizeTier[] memory emptyTiers = new IRips.PrizeTier[](0);

        vm.expectRevert(IRips.EmptyPrizeDistribution.selector);
        rips.updateStake(
            stakeId,
            IRips.Config({
                currency: address(0),
                prizeDistribution: emptyTiers,
                ticketCap: DEFAULT_TICKET_CAP,
                duration: DEFAULT_DURATION,
                ticketCost: DEFAULT_TICKET_COST,
                feePercent: DEFAULT_FEE_PERCENT
            })
        );
    }

    function test_RevertWhen_ATierHasMinPrizeGreaterThanMaxPrize()
        external
        whenTheCallerIsTheOwner
    {
        // it should revert.
        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: uint64(DEFAULT_TICKET_CAP), minPrize: 2 ether, maxPrize: 1 ether
        });

        vm.expectRevert(IRips.InvalidPrizeRange.selector);
        rips.updateStake(
            stakeId,
            IRips.Config({
                currency: address(0),
                prizeDistribution: tiers,
                ticketCap: DEFAULT_TICKET_CAP,
                duration: DEFAULT_DURATION,
                ticketCost: DEFAULT_TICKET_COST,
                feePercent: DEFAULT_FEE_PERCENT
            })
        );
    }

    function test_RevertWhen_TotalPrizeCountDoesNotEqualTicketCap()
        external
        whenTheCallerIsTheOwner
    {
        // it should revert.
        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: uint64(DEFAULT_TICKET_CAP - 1),
            minPrize: uint128(DEFAULT_TICKET_COST),
            maxPrize: uint128(DEFAULT_TICKET_COST)
        });

        vm.expectRevert(IRips.PrizeCountMismatch.selector);
        rips.updateStake(
            stakeId,
            IRips.Config({
                currency: address(0),
                prizeDistribution: tiers,
                ticketCap: DEFAULT_TICKET_CAP,
                duration: DEFAULT_DURATION,
                ticketCost: DEFAULT_TICKET_COST,
                feePercent: DEFAULT_FEE_PERCENT
            })
        );
    }

    function test_RevertWhen_TotalPrizePoolDoesNotEqualTicketCapTimesTicketCost()
        external
        whenTheCallerIsTheOwner
    {
        // it should revert.
        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: uint64(DEFAULT_TICKET_CAP),
            minPrize: uint128(DEFAULT_TICKET_COST + 1),
            maxPrize: uint128(DEFAULT_TICKET_COST + 1)
        });

        vm.expectRevert(IRips.PrizePoolMismatch.selector);
        rips.updateStake(
            stakeId,
            IRips.Config({
                currency: address(0),
                prizeDistribution: tiers,
                ticketCap: DEFAULT_TICKET_CAP,
                duration: DEFAULT_DURATION,
                ticketCost: DEFAULT_TICKET_COST,
                feePercent: DEFAULT_FEE_PERCENT
            })
        );
    }

    function test_RevertWhen_FeePercentExceeds10000() external whenTheCallerIsTheOwner {
        // it should revert.
        IRips.Config memory config = _updatedConfig();
        config.feePercent = 10001;

        vm.expectRevert(IRips.FeeTooHigh.selector);
        rips.updateStake(stakeId, config);
    }

    function test_WhenTheConfigIsValid() external whenTheCallerIsTheOwner {
        // it should store the config as pending.
        // it should emit a {StakeUpdated} event.
        IRips.Config memory config = _updatedConfig();

        vm.expectEmit();
        emit IRips.StakeUpdated(stakeId);

        rips.updateStake(stakeId, config);

        assertTrue(rips.exposed_hasPendingConfig(stakeId));

        IRips.Config memory pending = rips.exposed_pendingConfig(stakeId);
        assertEq(pending.ticketCap, config.ticketCap);
        assertEq(pending.ticketCost, config.ticketCost);
        assertEq(pending.currency, config.currency);
        assertEq(pending.duration, config.duration);
        assertEq(pending.prizeDistribution.length, config.prizeDistribution.length);
        assertEq(pending.feePercent, config.feePercent);
    }

    function test_WhenTheNextRoundIsCreatedAfterAnUpdate() external whenTheCallerIsTheOwner {
        // it should apply the pending config to the active stake.
        // it should clear the pending config.
        IRips.Config memory config = _updatedConfig();

        rips.updateStake(stakeId, config);

        vm.stopPrank();

        vm.warp(block.timestamp + DEFAULT_DURATION + 1);

        uint256 newTicketCost = config.ticketCost;

        vm.deal(user, 100 ether);
        vm.prank(user);
        rips.buyTickets{value: newTicketCost}(stakeId, 1, user);

        IRips.Config memory active = rips.exposed_stakeConfig(stakeId);
        assertEq(active.ticketCap, config.ticketCap);
        assertEq(active.ticketCost, config.ticketCost);
        assertEq(active.currency, config.currency);
        assertEq(active.duration, config.duration);

        assertFalse(rips.exposed_hasPendingConfig(stakeId));
    }
}
