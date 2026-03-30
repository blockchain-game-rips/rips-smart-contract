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

    function _totalPrize() private pure returns (uint256) {
        return DEFAULT_TICKET_CAP * DEFAULT_TICKET_COST;
    }

    function _userPrize() private pure returns (uint256) {
        return _totalPrize() - _protocolFee();
    }

    function _protocolFee() private pure returns (uint256) {
        return (_totalPrize() * INITIAL_FEE_PERCENT) / 10_000;
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

    function test_WhenThereAreUnclaimedRanges_MarksRangesAsClaimed()
        external
        whenThereAreUnclaimedRanges
    {
        vm.prank(user);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user);

        IRips.TicketRange[] memory ranges = rips.getUserTickets(roundId, user);
        for (uint256 i = 0; i < ranges.length; i++) {
            assertTrue(ranges[i].claimed);
        }
    }

    function test_WhenThereAreUnclaimedRanges_CalculatesCorrectPrizes()
        external
        whenThereAreUnclaimedRanges
    {
        uint256 balanceBefore = user.balance;

        vm.prank(user);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user);

        assertEq(user.balance, balanceBefore + _userPrize());
    }

    function test_WhenRecipientIsDifferentFromTheCaller() external whenThereAreUnclaimedRanges {
        address caller = makeAddr("caller");

        uint256 recipientBalanceBefore = user.balance;
        uint256 callerBalanceBefore = caller.balance;

        vm.prank(caller);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user);

        assertEq(user.balance, recipientBalanceBefore + _userPrize());
        assertEq(caller.balance, callerBalanceBefore);
    }

    modifier givenTheStakeCurrencyIsNative() {
        _;
    }

    function test_WhenProtocolFeeIsZero()
        external
        whenThereAreUnclaimedRanges
        givenTheStakeCurrencyIsNative
    {
        vm.prank(owner);
        rips.setProtocolFee(0);

        uint256 balanceBefore = user.balance;

        vm.expectEmit();
        emit IRips.PrizesClaimed(roundId, user, DEFAULT_TICKET_CAP, _totalPrize());

        vm.prank(user);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user);

        assertEq(user.balance, balanceBefore + _totalPrize());
    }

    function test_WhenProtocolFeeIsGreaterThanZero()
        external
        whenThereAreUnclaimedRanges
        givenTheStakeCurrencyIsNative
    {
        uint256 userBalanceBefore = user.balance;
        uint256 feeRecipientBalanceBefore = owner.balance;

        vm.expectEmit();
        emit IRips.PrizesClaimed(roundId, user, DEFAULT_TICKET_CAP, _userPrize());

        vm.prank(user);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user);

        assertEq(user.balance, userBalanceBefore + _userPrize());
        assertEq(owner.balance, feeRecipientBalanceBefore + _protocolFee());
    }

    modifier givenTheStakeCurrencyIsAnERC20Token() {
        _mintAndApprove(user, DEFAULT_TICKET_CAP * DEFAULT_TICKET_COST);

        uint256 erc20StakeId = _createDefaultERC20Stake();
        roundId = rips.exposed_stakeToActiveRound(erc20StakeId);

        vm.prank(user);
        rips.buyTickets(erc20StakeId, DEFAULT_TICKET_CAP, user);

        uint256 vrfRequestId = rips.requestRandomness(roundId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));
        _;
    }

    function test_WhenProtocolFeeIsZero_GivenTheStakeCurrencyIsAnERC20Token()
        external
        givenTheStakeCurrencyIsAnERC20Token
    {
        vm.prank(owner);
        rips.setProtocolFee(0);

        uint256 balanceBefore = erc20.balanceOf(user);

        vm.expectEmit();
        emit IRips.PrizesClaimed(roundId, user, DEFAULT_TICKET_CAP, _totalPrize());

        vm.prank(user);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user);

        assertEq(erc20.balanceOf(user), balanceBefore + _totalPrize());
    }

    function test_WhenProtocolFeeIsGreaterThanZero_GivenTheStakeCurrencyIsAnERC20Token()
        external
        givenTheStakeCurrencyIsAnERC20Token
    {
        uint256 userBalanceBefore = erc20.balanceOf(user);
        uint256 feeRecipientBalanceBefore = erc20.balanceOf(owner);

        vm.expectEmit();
        emit IRips.PrizesClaimed(roundId, user, DEFAULT_TICKET_CAP, _userPrize());

        vm.prank(user);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user);

        assertEq(erc20.balanceOf(user), userBalanceBefore + _userPrize());
        assertEq(erc20.balanceOf(owner), feeRecipientBalanceBefore + _protocolFee());
    }
}
