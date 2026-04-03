// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";

contract Rips_GetUserTickets is RipsTestBase {
    uint256 private stakeId;
    uint256 private roundId;

    function setUp() public override {
        super.setUp();

        stakeId = _createDefaultStake();
    }

    function test_WhenTheUserHasNoTicketsInTheRound() external {
        // round doesn't exist yet — no tickets bought — empty array expected
        uint256 nextRoundId = rips.exposed_nextRoundId();
        IRips.TicketRange[] memory ranges = rips.getUserTickets(nextRoundId, user);
        assertEq(ranges.length, 0);
    }

    function test_WhenTheUserHasTicketsInTheRound() external {
        uint256 ticketCount = 2;

        vm.deal(user, ticketCount * DEFAULT_TICKET_COST);
        vm.prank(user);
        rips.buyTickets{value: ticketCount * DEFAULT_TICKET_COST}(stakeId, ticketCount, user);

        roundId = rips.stakeIdToCurrentRoundId(stakeId);
        IRips.TicketRange[] memory ranges = rips.getUserTickets(roundId, user);
        assertEq(ranges.length, 1);
        assertEq(ranges[0].start, 0);
        assertEq(ranges[0].count, ticketCount);
        assertFalse(ranges[0].claimed);
    }
}
