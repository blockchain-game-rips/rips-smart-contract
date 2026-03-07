// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";

contract Rips_GetUserTickets is RipsTestBase {
    uint256 private constant TICKET_CAP = 4;
    uint256 private constant TICKET_COST = 1 ether;
    uint256 private constant DURATION = 1 days;

    uint256 private stakeId;
    uint256 private roundId;

    function setUp() public override {
        super.setUp();

        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] =
            IRips.PrizeTier({prizeCount: TICKET_CAP, minPrize: TICKET_COST, maxPrize: TICKET_COST});

        vm.prank(owner);
        stakeId = rips.createStake(
            IRips.StakeConfig({
                prizeDistribution: tiers,
                ticketCap: TICKET_CAP,
                duration: DURATION,
                ticketCost: TICKET_COST
            })
        );

        roundId = rips.exposed_stakeToActiveRound(stakeId);
    }

    function test_WhenTheUserHasNoTicketsInTheRound() external view {
        IRips.TicketRange[] memory ranges = rips.getUserTickets(roundId, user);
        assertEq(ranges.length, 0);
    }

    function test_WhenTheUserHasTicketsInTheRound() external {
        uint256 ticketCount = 2;

        vm.deal(user, ticketCount * TICKET_COST);
        vm.prank(user);
        rips.buyTickets{value: ticketCount * TICKET_COST}(stakeId, ticketCount, user);

        IRips.TicketRange[] memory ranges = rips.getUserTickets(roundId, user);
        assertEq(ranges.length, 1);
        assertEq(ranges[0].start, 0);
        assertEq(ranges[0].count, ticketCount);
        assertFalse(ranges[0].claimed);
    }
}
