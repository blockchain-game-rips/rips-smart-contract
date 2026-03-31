// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";

contract Rips_BuyTickets is RipsTestBase {
    uint256 private stakeId;
    uint256 private roundId;
    uint256 private ticketsToBuy;

    function setUp() public override {
        super.setUp();

        stakeId = _createDefaultStake();
        roundId = rips.exposed_stakeToActiveRound(stakeId);

        vm.deal(user, 100 ether);
    }

    function test_RevertWhen_TheContractIsPaused() external {
        vm.prank(owner);
        rips.pause();

        vm.prank(user);
        vm.expectRevert();
        rips.buyTickets{value: DEFAULT_TICKET_COST}(stakeId, 1, user);
    }

    function test_RevertWhen_RecipientIsZeroAddress() external {
        vm.prank(user);
        vm.expectRevert();
        rips.buyTickets{value: DEFAULT_TICKET_COST}(stakeId, 1, address(0));
    }

    function test_RevertWhen_TheStakeDoesNotExist() external {
        uint256 nonExistentStakeId = 999;

        vm.prank(user);
        vm.expectRevert(IRips.StakeNotExist.selector);
        rips.buyTickets{value: DEFAULT_TICKET_COST}(nonExistentStakeId, 1, user);
    }

    function test_RevertWhen_TheActiveRoundHasExpiredAndTheStakeIsDeleted() external {
        vm.prank(owner);
        rips.deleteStake(stakeId);

        vm.warp(block.timestamp + DEFAULT_DURATION + 1);

        vm.prank(user);
        vm.expectRevert(IRips.StakeNotExist.selector);
        rips.buyTickets{value: DEFAULT_TICKET_COST}(stakeId, 1, user);
    }

    function test_WhenTheActiveRoundHasExpiredAndTheStakeIsNotDeleted() external {
        vm.warp(block.timestamp + DEFAULT_DURATION + 1);

        uint256 expectedNewRoundId = rips.exposed_nextRoundId();

        vm.expectEmit();
        emit IRips.RoundCreated(expectedNewRoundId, stakeId);

        vm.prank(user);
        rips.buyTickets{value: DEFAULT_TICKET_COST}(stakeId, 1, user);

        uint256 newRoundId = rips.exposed_stakeToActiveRound(stakeId);
        assertNotEq(newRoundId, roundId);
    }

    function test_RevertWhen_TicketCountIsZero() external {
        vm.prank(user);
        vm.expectRevert(IRips.ZeroTickets.selector);
        rips.buyTickets{value: 0}(stakeId, 0, user);
    }

    modifier givenTheStakeCurrencyIsNative() {
        _;
    }

    modifier whenRequestedTicketsAreFewerThanAvailable() {
        ticketsToBuy = 2;
        _;
    }

    modifier whenRequestedTicketsEqualTheRemainingCapacity() {
        ticketsToBuy = DEFAULT_TICKET_CAP;
        _;
    }

    function test_RevertWhen_ThePaymentAmountIsIncorrect() external givenTheStakeCurrencyIsNative {
        vm.prank(user);
        vm.expectRevert(IRips.IncorrectPayment.selector);
        rips.buyTickets{value: DEFAULT_TICKET_COST - 1}(stakeId, 1, user);
    }

    function test_WhenRequestedTicketsAreFewerThanAvailable_GivenNative()
        external
        givenTheStakeCurrencyIsNative
        whenRequestedTicketsAreFewerThanAvailable
    {
        vm.expectEmit();
        emit IRips.TicketsPurchased(roundId, user, ticketsToBuy, 0);

        vm.prank(user);
        rips.buyTickets{value: ticketsToBuy * DEFAULT_TICKET_COST}(stakeId, ticketsToBuy, user);

        IRips.Round memory round = rips.exposed_round(roundId);
        assertEq(round.ticketsSold, ticketsToBuy);

        IRips.TicketRange[] memory ranges = rips.getUserTickets(roundId, user);
        assertEq(ranges.length, 1);
        assertEq(ranges[0].start, 0);
        assertEq(ranges[0].count, ticketsToBuy);
    }

    function test_WhenRecipientIsDifferentFromTheCaller()
        external
        givenTheStakeCurrencyIsNative
        whenRequestedTicketsAreFewerThanAvailable
    {
        address recipient = makeAddr("recipient");

        vm.prank(user);
        rips.buyTickets{value: ticketsToBuy * DEFAULT_TICKET_COST}(stakeId, ticketsToBuy, recipient);

        IRips.TicketRange[] memory recipientRanges = rips.getUserTickets(roundId, recipient);
        assertEq(recipientRanges.length, 1);
        assertEq(recipientRanges[0].count, ticketsToBuy);

        IRips.TicketRange[] memory callerRanges = rips.getUserTickets(roundId, user);
        assertEq(callerRanges.length, 0);
    }

    function test_WhenTicketCountExceedsMAX_TICKETS_PER_RANGE()
        external
        givenTheStakeCurrencyIsNative
        whenRequestedTicketsAreFewerThanAvailable
    {
        uint256 largeTicketCap = 2048;
        uint256 ticketCost = 0.01 ether;

        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: uint64(largeTicketCap),
            minPrize: uint128(ticketCost),
            maxPrize: uint128(ticketCost)
        });

        vm.prank(owner);
        uint256 largeStakeId = rips.createStake(
            IRips.StakeConfig({
                currency: address(0),
                prizeDistribution: tiers,
                ticketCap: largeTicketCap,
                duration: DEFAULT_DURATION,
                ticketCost: ticketCost,
                feePercent: 0
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

    function test_WhenRequestedTicketsEqualTheRemainingCapacity()
        external
        givenTheStakeCurrencyIsNative
        whenRequestedTicketsEqualTheRemainingCapacity
    {
        vm.expectEmit();
        emit IRips.TicketsPurchased(roundId, user, ticketsToBuy, 0);

        vm.prank(user);
        rips.buyTickets{value: ticketsToBuy * DEFAULT_TICKET_COST}(stakeId, ticketsToBuy, user);

        IRips.Round memory round = rips.exposed_round(roundId);
        assertEq(round.ticketsSold, DEFAULT_TICKET_CAP);
        assertEq(uint256(round.status), uint256(IRips.RoundStatus.SoldOut));
    }

    function test_GivenTheStakeIsNotDeleted()
        external
        givenTheStakeCurrencyIsNative
        whenRequestedTicketsEqualTheRemainingCapacity
    {
        uint256 expectedNewRoundId = rips.exposed_nextRoundId();

        vm.prank(user);
        rips.buyTickets{value: ticketsToBuy * DEFAULT_TICKET_COST}(stakeId, ticketsToBuy, user);

        uint256 newActiveRound = rips.exposed_stakeToActiveRound(stakeId);
        assertEq(newActiveRound, expectedNewRoundId);
        assertNotEq(newActiveRound, roundId);
    }

    function test_GivenTheStakeIsDeleted()
        external
        givenTheStakeCurrencyIsNative
        whenRequestedTicketsEqualTheRemainingCapacity
    {
        vm.prank(owner);
        rips.deleteStake(stakeId);

        vm.prank(user);
        rips.buyTickets{value: ticketsToBuy * DEFAULT_TICKET_COST}(stakeId, ticketsToBuy, user);

        uint256 activeRound = rips.exposed_stakeToActiveRound(stakeId);
        assertEq(activeRound, 0);
    }

    function test_WhenRequestedTicketsExceedAvailableTickets()
        external
        givenTheStakeCurrencyIsNative
    {
        uint256 initialBuy = DEFAULT_TICKET_CAP - 1;
        vm.prank(user);
        rips.buyTickets{value: initialBuy * DEFAULT_TICKET_COST}(stakeId, initialBuy, user);

        ticketsToBuy = 3;
        uint256 availableTickets = DEFAULT_TICKET_CAP - initialBuy;
        uint256 payment = ticketsToBuy * DEFAULT_TICKET_COST;
        uint256 expectedRefund = (ticketsToBuy - availableTickets) * DEFAULT_TICKET_COST;

        uint256 balanceBefore = user.balance;

        vm.expectEmit();
        emit IRips.TicketsPurchased(roundId, user, availableTickets, initialBuy);

        vm.prank(user);
        rips.buyTickets{value: payment}(stakeId, ticketsToBuy, user);

        IRips.Round memory round = rips.exposed_round(roundId);
        assertEq(round.ticketsSold, DEFAULT_TICKET_CAP);
        assertEq(uint256(round.status), uint256(IRips.RoundStatus.SoldOut));

        assertEq(user.balance, balanceBefore - payment + expectedRefund);
    }

    modifier givenTheStakeCurrencyIsAnERC20Token() {
        stakeId = _createDefaultERC20Stake();
        roundId = rips.exposed_stakeToActiveRound(stakeId);
        _mintAndApprove(user, 100 ether);
        _;
    }

    function test_RevertWhen_ETHIsSent() external givenTheStakeCurrencyIsAnERC20Token {
        vm.prank(user);
        vm.expectRevert(IRips.EthSentForERC20.selector);
        rips.buyTickets{value: 1}(stakeId, 1, user);
    }

    function test_WhenRequestedTicketsAreFewerThanAvailable()
        external
        givenTheStakeCurrencyIsAnERC20Token
        whenRequestedTicketsAreFewerThanAvailable
    {
        uint256 expectedCost = ticketsToBuy * DEFAULT_TICKET_COST;
        uint256 balanceBefore = erc20.balanceOf(user);

        vm.expectEmit();
        emit IRips.TicketsPurchased(roundId, user, ticketsToBuy, 0);

        vm.prank(user);
        rips.buyTickets(stakeId, ticketsToBuy, user);

        assertEq(erc20.balanceOf(user), balanceBefore - expectedCost);

        IRips.Round memory round = rips.exposed_round(roundId);
        assertEq(round.ticketsSold, ticketsToBuy);

        IRips.TicketRange[] memory ranges = rips.getUserTickets(roundId, user);
        assertEq(ranges.length, 1);
        assertEq(ranges[0].count, ticketsToBuy);
    }

    function test_WhenRecipientIsDifferentFromTheCaller_GivenERC20()
        external
        givenTheStakeCurrencyIsAnERC20Token
        whenRequestedTicketsAreFewerThanAvailable
    {
        address recipient = makeAddr("recipient");

        vm.prank(user);
        rips.buyTickets(stakeId, ticketsToBuy, recipient);

        IRips.TicketRange[] memory recipientRanges = rips.getUserTickets(roundId, recipient);
        assertEq(recipientRanges.length, 1);
        assertEq(recipientRanges[0].count, ticketsToBuy);

        IRips.TicketRange[] memory callerRanges = rips.getUserTickets(roundId, user);
        assertEq(callerRanges.length, 0);
    }

    function test_WhenTicketCountExceedsMAX_TICKETS_PER_RANGE_GivenERC20()
        external
        givenTheStakeCurrencyIsAnERC20Token
        whenRequestedTicketsAreFewerThanAvailable
    {
        uint256 largeTicketCap = 2048;
        uint256 ticketCost = 0.01 ether;

        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: uint64(largeTicketCap),
            minPrize: uint128(ticketCost),
            maxPrize: uint128(ticketCost)
        });

        vm.prank(owner);
        uint256 largeStakeId = rips.createStake(
            IRips.StakeConfig({
                currency: address(erc20),
                prizeDistribution: tiers,
                ticketCap: largeTicketCap,
                duration: DEFAULT_DURATION,
                ticketCost: ticketCost,
                feePercent: 0
            })
        );
        uint256 largeRoundId = rips.exposed_stakeToActiveRound(largeStakeId);

        ticketsToBuy = 1500;

        vm.prank(user);
        rips.buyTickets(largeStakeId, ticketsToBuy, user);

        IRips.TicketRange[] memory ranges = rips.getUserTickets(largeRoundId, user);
        assertEq(ranges.length, 2);
        assertEq(ranges[0].count, 1000);
        assertEq(ranges[1].count, 500);
    }

    function test_WhenRequestedTicketsEqualTheRemainingCapacity_GivenERC20()
        external
        givenTheStakeCurrencyIsAnERC20Token
        whenRequestedTicketsEqualTheRemainingCapacity
    {
        uint256 expectedCost = DEFAULT_TICKET_CAP * DEFAULT_TICKET_COST;
        uint256 balanceBefore = erc20.balanceOf(user);

        vm.expectEmit();
        emit IRips.TicketsPurchased(roundId, user, ticketsToBuy, 0);

        vm.prank(user);
        rips.buyTickets(stakeId, ticketsToBuy, user);

        assertEq(erc20.balanceOf(user), balanceBefore - expectedCost);

        IRips.Round memory round = rips.exposed_round(roundId);
        assertEq(round.ticketsSold, DEFAULT_TICKET_CAP);
        assertEq(uint256(round.status), uint256(IRips.RoundStatus.SoldOut));
    }

    function test_WhenRequestedTicketsExceedAvailableTickets_GivenERC20()
        external
        givenTheStakeCurrencyIsAnERC20Token
    {
        uint256 initialBuy = DEFAULT_TICKET_CAP - 1;
        vm.prank(user);
        rips.buyTickets(stakeId, initialBuy, user);

        ticketsToBuy = 3;
        uint256 availableTickets = DEFAULT_TICKET_CAP - initialBuy;
        uint256 expectedCost = availableTickets * DEFAULT_TICKET_COST;
        uint256 balanceBefore = erc20.balanceOf(user);

        vm.expectEmit();
        emit IRips.TicketsPurchased(roundId, user, availableTickets, initialBuy);

        vm.prank(user);
        rips.buyTickets(stakeId, ticketsToBuy, user);

        assertEq(erc20.balanceOf(user), balanceBefore - expectedCost);

        IRips.Round memory round = rips.exposed_round(roundId);
        assertEq(round.ticketsSold, DEFAULT_TICKET_CAP);
        assertEq(uint256(round.status), uint256(IRips.RoundStatus.SoldOut));
    }
}
