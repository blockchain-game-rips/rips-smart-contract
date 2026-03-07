// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";

contract Rips_BuyTickets is RipsTestBase {
    uint256 private constant TICKET_CAP = 4;
    uint256 private constant TICKET_COST = 1 ether;
    uint256 private constant DURATION = 1 days;

    uint256 private stakeId;
    uint256 private roundId;
    uint256 private ticketsToBuy;

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

        vm.deal(user, 100 ether);
    }

    function test_RevertWhen_TheContractIsPaused() external {
        vm.prank(owner);
        rips.pause();

        vm.prank(user);
        vm.expectRevert();
        rips.buyTickets{value: TICKET_COST}(stakeId, 1, user);
    }

    function test_RevertWhen_RecipientIsZeroAddress() external {
        vm.prank(user);
        vm.expectRevert();
        rips.buyTickets{value: TICKET_COST}(stakeId, 1, address(0));
    }

    function test_RevertWhen_TheStakeDoesNotExist() external {
        uint256 nonExistentStakeId = 999;

        vm.prank(user);
        vm.expectRevert(IRips.StakeNotExist.selector);
        rips.buyTickets{value: TICKET_COST}(nonExistentStakeId, 1, user);
    }

    function test_RevertWhen_TheActiveRoundHasExpiredAndTheStakeIsDeleted() external {
        vm.prank(owner);
        rips.deleteStake(stakeId);

        vm.warp(block.timestamp + DURATION + 1);

        vm.prank(user);
        vm.expectRevert(IRips.StakeNotExist.selector);
        rips.buyTickets{value: TICKET_COST}(stakeId, 1, user);
    }

    function test_WhenTheActiveRoundHasExpiredAndTheStakeIsNotDeleted() external {
        vm.warp(block.timestamp + DURATION + 1);

        uint256 expectedNewRoundId = rips.exposed_nextRoundId();

        vm.expectEmit();
        emit IRips.RoundCreated(expectedNewRoundId, stakeId, block.timestamp);

        vm.prank(user);
        rips.buyTickets{value: TICKET_COST}(stakeId, 1, user);

        uint256 newRoundId = rips.exposed_stakeToActiveRound(stakeId);
        assertNotEq(newRoundId, roundId);
    }

    function test_RevertWhen_TicketCountIsZero() external {
        vm.prank(user);
        vm.expectRevert(IRips.ZeroTickets.selector);
        rips.buyTickets{value: 0}(stakeId, 0, user);
    }

    function test_RevertWhen_ThePaymentAmountIsIncorrect() external {
        vm.prank(user);
        vm.expectRevert(IRips.IncorrectPayment.selector);
        rips.buyTickets{value: TICKET_COST + 1}(stakeId, 1, user);
    }

    modifier whenRequestedTicketsAreFewerThanAvailable() {
        ticketsToBuy = 2;
        _;
    }

    function test_WhenRequestedTicketsAreFewerThanAvailable()
        external
        whenRequestedTicketsAreFewerThanAvailable
    {
        vm.expectEmit();
        emit IRips.TicketsPurchased(roundId, user, 0, ticketsToBuy);

        vm.prank(user);
        rips.buyTickets{value: ticketsToBuy * TICKET_COST}(stakeId, ticketsToBuy, user);

        IRips.Round memory round = rips.exposed_round(roundId);
        assertEq(round.ticketsSold, ticketsToBuy);

        IRips.TicketRange[] memory ranges = rips.getUserTickets(roundId, user);
        assertEq(ranges.length, 1);
        assertEq(ranges[0].start, 0);
        assertEq(ranges[0].count, ticketsToBuy);
    }

    function test_WhenRecipientIsDifferentFromTheCaller()
        external
        whenRequestedTicketsAreFewerThanAvailable
    {
        address recipient = makeAddr("recipient");

        vm.prank(user);
        rips.buyTickets{value: ticketsToBuy * TICKET_COST}(stakeId, ticketsToBuy, recipient);

        IRips.TicketRange[] memory recipientRanges = rips.getUserTickets(roundId, recipient);
        assertEq(recipientRanges.length, 1);
        assertEq(recipientRanges[0].count, ticketsToBuy);

        IRips.TicketRange[] memory callerRanges = rips.getUserTickets(roundId, user);
        assertEq(callerRanges.length, 0);
    }

    function test_WhenTicketCountExceedsMAX_TICKETS_PER_RANGE()
        external
        whenRequestedTicketsAreFewerThanAvailable
    {
        uint256 largeTicketCap = 2048;
        uint256 ticketCost = 0.01 ether;

        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: largeTicketCap, minPrize: ticketCost, maxPrize: ticketCost
        });

        vm.prank(owner);
        uint256 largeStakeId = rips.createStake(
            IRips.StakeConfig({
                prizeDistribution: tiers,
                ticketCap: largeTicketCap,
                duration: DURATION,
                ticketCost: ticketCost
            })
        );
        uint256 largeRoundId = rips.exposed_stakeToActiveRound(largeStakeId);

        ticketsToBuy = 1500;

        vm.prank(user);
        rips.buyTickets{value: ticketsToBuy * ticketCost}(largeStakeId, ticketsToBuy, user);

        IRips.TicketRange[] memory ranges = rips.getUserTickets(largeRoundId, user);
        assertEq(ranges.length, 2);
        assertEq(ranges[0].count, 1000);
        assertEq(ranges[1].count, 500);
    }

    modifier whenRequestedTicketsEqualTheRemainingCapacity() {
        ticketsToBuy = TICKET_CAP;
        _;
    }

    function test_WhenRequestedTicketsEqualTheRemainingCapacity()
        external
        whenRequestedTicketsEqualTheRemainingCapacity
    {
        vm.expectEmit();
        emit IRips.TicketsPurchased(roundId, user, 0, ticketsToBuy);

        vm.prank(user);
        rips.buyTickets{value: ticketsToBuy * TICKET_COST}(stakeId, ticketsToBuy, user);

        IRips.Round memory round = rips.exposed_round(roundId);
        assertEq(round.ticketsSold, TICKET_CAP);
        assertEq(uint256(round.status), uint256(IRips.RoundStatus.SoldOut));
    }

    function test_GivenTheStakeIsNotDeleted()
        external
        whenRequestedTicketsEqualTheRemainingCapacity
    {
        uint256 expectedNewRoundId = rips.exposed_nextRoundId();

        vm.prank(user);
        rips.buyTickets{value: ticketsToBuy * TICKET_COST}(stakeId, ticketsToBuy, user);

        uint256 newActiveRound = rips.exposed_stakeToActiveRound(stakeId);
        assertEq(newActiveRound, expectedNewRoundId);
        assertNotEq(newActiveRound, roundId);
    }

    function test_GivenTheStakeIsDeleted() external whenRequestedTicketsEqualTheRemainingCapacity {
        vm.prank(owner);
        rips.deleteStake(stakeId);

        vm.prank(user);
        rips.buyTickets{value: ticketsToBuy * TICKET_COST}(stakeId, ticketsToBuy, user);

        uint256 activeRound = rips.exposed_stakeToActiveRound(stakeId);
        assertEq(activeRound, 0);
    }

    function test_WhenRequestedTicketsExceedAvailableTickets() external {
        uint256 initialBuy = TICKET_CAP - 1;
        vm.prank(user);
        rips.buyTickets{value: initialBuy * TICKET_COST}(stakeId, initialBuy, user);

        ticketsToBuy = 3;
        uint256 availableTickets = TICKET_CAP - initialBuy;
        uint256 payment = ticketsToBuy * TICKET_COST;
        uint256 expectedRefund = (ticketsToBuy - availableTickets) * TICKET_COST;

        uint256 balanceBefore = user.balance;

        vm.expectEmit();
        emit IRips.TicketsPurchased(roundId, user, initialBuy, availableTickets);

        vm.prank(user);
        rips.buyTickets{value: payment}(stakeId, ticketsToBuy, user);

        IRips.Round memory round = rips.exposed_round(roundId);
        assertEq(round.ticketsSold, TICKET_CAP);
        assertEq(uint256(round.status), uint256(IRips.RoundStatus.SoldOut));

        uint256 balanceAfter = user.balance;
        assertEq(balanceAfter, balanceBefore - payment + expectedRefund);
    }
}
