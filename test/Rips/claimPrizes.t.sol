// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";

contract Rips_ClaimPrizes is RipsTestBase {
    uint256 private constant START_INDEX = 0;
    uint256 private constant MAX_RANGES = 10;

    uint256 private stakeId;
    uint256 private roundId;

    function setUp() public override {
        super.setUp();

        vrfCoordinator.fundSubscription(vrfSubscriptionId, 100 ether);

        stakeId = _createDefaultStake();
        roundId = rips.exposed_stakeToActiveRound(stakeId);

        vm.deal(user, 100 ether);
        vm.prank(user);
        rips.buyTickets{value: DEFAULT_TICKET_CAP * DEFAULT_TICKET_COST}(
            stakeId, DEFAULT_TICKET_CAP, user
        );
    }

    function _finalizeRound() private {
        uint256 vrfRequestId = rips.requestRandomness(roundId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));
    }

    function test_RevertWhen_TheRoundIsNotFinalized() external {
        vm.prank(user);
        vm.expectRevert(IRips.RoundNotFinalized.selector);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user);
    }

    function test_RevertWhen_RecipientIsZeroAddress() external {
        _finalizeRound();

        vm.prank(user);
        vm.expectRevert();
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, address(0));
    }

    function test_RevertWhen_StartIndexIsOutOfBounds() external {
        _finalizeRound();

        IRips.TicketRange[] memory ranges = rips.getUserTickets(roundId, user);
        uint256 outOfBoundsIndex = ranges.length;

        vm.prank(user);
        vm.expectRevert(IRips.InvalidStartIndex.selector);
        rips.claimPrizes(roundId, outOfBoundsIndex, MAX_RANGES, user);
    }

    function test_WhenAllRangesInScopeAreAlreadyClaimed() external {
        _finalizeRound();

        vm.prank(user);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user);

        uint256 balanceBefore = user.balance;

        vm.prank(user);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user);

        assertEq(user.balance, balanceBefore);
    }

    modifier whenThereAreUnclaimedRanges() {
        _finalizeRound();
        _;
    }

    function test_WhenThereAreUnclaimedRanges() external whenThereAreUnclaimedRanges {
        vm.prank(user);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user);

        IRips.TicketRange[] memory ranges = rips.getUserTickets(roundId, user);
        for (uint256 i = 0; i < ranges.length; i++) {
            assertTrue(ranges[i].claimed);
        }
    }

    function test_WhenRecipientIsDifferentFromTheCaller() external whenThereAreUnclaimedRanges {
        address caller = makeAddr("caller");

        uint256 totalPrize = DEFAULT_TICKET_CAP * DEFAULT_TICKET_COST;
        uint256 protocolFee = (totalPrize * INITIAL_FEE_PERCENT) / 10_000;
        uint256 userPrize = totalPrize - protocolFee;

        uint256 recipientBalanceBefore = user.balance;
        uint256 callerBalanceBefore = caller.balance;

        vm.prank(caller);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user);

        assertEq(user.balance, recipientBalanceBefore + userPrize);
        assertEq(caller.balance, callerBalanceBefore);
    }

    function test_WhenProtocolFeeIsZero() external whenThereAreUnclaimedRanges {
        vm.prank(owner);
        rips.setProtocolFee(0);

        uint256 totalPrize = DEFAULT_TICKET_CAP * DEFAULT_TICKET_COST;
        uint256 balanceBefore = user.balance;

        vm.expectEmit();
        emit IRips.PrizesClaimed(roundId, user, totalPrize);

        vm.prank(user);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user);

        assertEq(user.balance, balanceBefore + totalPrize);
    }

    function test_WhenProtocolFeeIsGreaterThanZero() external whenThereAreUnclaimedRanges {
        uint256 totalPrize = DEFAULT_TICKET_CAP * DEFAULT_TICKET_COST;
        uint256 protocolFee = (totalPrize * INITIAL_FEE_PERCENT) / 10_000;
        uint256 userPrize = totalPrize - protocolFee;

        uint256 userBalanceBefore = user.balance;
        uint256 feeRecipientBalanceBefore = owner.balance;

        vm.expectEmit();
        emit IRips.PrizesClaimed(roundId, user, userPrize);

        vm.prank(user);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user);

        assertEq(user.balance, userBalanceBefore + userPrize);
        assertEq(owner.balance, feeRecipientBalanceBefore + protocolFee);
    }
}
