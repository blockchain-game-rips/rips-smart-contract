// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";

contract Rips_Refund is RipsTestBase {
    uint256 private constant TICKET_CAP = 4;
    uint256 private constant TICKET_COST = 1 ether;
    uint256 private constant DURATION = 1 days;
    uint256 private constant TICKETS_BOUGHT = 2;

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

        vm.deal(user, 100 ether);
        vm.prank(user);
        rips.buyTickets{value: TICKETS_BOUGHT * TICKET_COST}(stakeId, TICKETS_BOUGHT, user);
    }

    function test_RevertWhen_TheRoundDoesNotExist() external {
        uint256 nonExistentRoundId = 999;

        vm.prank(user);
        vm.expectRevert(IRips.RoundNotExist.selector);
        rips.refund(nonExistentRoundId, user);
    }

    function test_RevertWhen_RecipientIsZeroAddress() external {
        vm.prank(user);
        vm.expectRevert();
        rips.refund(roundId, address(0));
    }

    function test_RevertWhen_TheRoundIsNotExpired() external {
        vm.prank(user);
        vm.expectRevert(IRips.RoundNotExpired.selector);
        rips.refund(roundId, user);
    }

    function test_RevertWhen_TheRecipientHasAlreadyBeenRefunded() external {
        vm.warp(block.timestamp + DURATION + 1);

        vm.prank(user);
        rips.refund(roundId, user);

        vm.prank(user);
        vm.expectRevert(IRips.AlreadyRefunded.selector);
        rips.refund(roundId, user);
    }

    function test_RevertWhen_TheRecipientHasNoTicketsInTheRound() external {
        vm.warp(block.timestamp + DURATION + 1);

        address noTickets = makeAddr("noTickets");

        vm.prank(noTickets);
        vm.expectRevert(IRips.NoTicketsToRefund.selector);
        rips.refund(roundId, noTickets);
    }

    modifier whenTheRecipientHasTicketsInTheRound() {
        vm.warp(block.timestamp + DURATION + 1);
        _;
    }

    function test_WhenTheRecipientHasTicketsInTheRound()
        external
        whenTheRecipientHasTicketsInTheRound
    {
        uint256 expectedRefund = TICKETS_BOUGHT * TICKET_COST;
        uint256 balanceBefore = user.balance;

        vm.expectEmit();
        emit IRips.RefundIssued(roundId, user, expectedRefund);

        vm.prank(user);
        rips.refund(roundId, user);

        assertEq(user.balance, balanceBefore + expectedRefund);

        vm.prank(user);
        vm.expectRevert(IRips.AlreadyRefunded.selector);
        rips.refund(roundId, user);
    }

    function test_WhenRecipientIsDifferentFromTheCaller()
        external
        whenTheRecipientHasTicketsInTheRound
    {
        address caller = makeAddr("caller");
        uint256 expectedRefund = TICKETS_BOUGHT * TICKET_COST;

        uint256 recipientBalanceBefore = user.balance;
        uint256 callerBalanceBefore = caller.balance;

        vm.prank(caller);
        rips.refund(roundId, user);

        assertEq(user.balance, recipientBalanceBefore + expectedRefund);
        assertEq(caller.balance, callerBalanceBefore);
    }
}
