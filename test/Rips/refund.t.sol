// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";

contract Rips_Refund is RipsTestBase {
    uint256 private constant TICKETS_BOUGHT = 2;

    uint256 private stakeId;
    uint256 private roundId;

    function setUp() public override {
        super.setUp();

        stakeId = _createDefaultStake();

        vm.deal(user, 100 ether);
        vm.prank(user);
        rips.buyTickets{value: TICKETS_BOUGHT * DEFAULT_TICKET_COST}(stakeId, TICKETS_BOUGHT, user);

        roundId = rips.stakeIdToCurrentRoundId(stakeId);
    }

    function _expectedRefundAmount() private pure returns (uint256) {
        return TICKETS_BOUGHT * DEFAULT_TICKET_COST;
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

    uint256 private constant VRF_EXPIRY = 7 weeks;

    function test_RevertWhen_TheRoundIsNotSoldOutButHasNotPassedItsDuration() external {
        vm.prank(user);
        vm.expectRevert(IRips.RoundNotExpired.selector);
        rips.refund(roundId, user);
    }

    function test_RevertWhen_TheRoundIsSoldOutAndTheVRFRequestHasNotExpired() external {
        vrfCoordinator.fundSubscription(vrfSubscriptionId, 100 ether);

        vm.deal(user, (DEFAULT_TICKET_CAP - TICKETS_BOUGHT) * DEFAULT_TICKET_COST);
        vm.prank(user);
        rips.buyTickets{value: (DEFAULT_TICKET_CAP - TICKETS_BOUGHT) * DEFAULT_TICKET_COST}(
            stakeId, DEFAULT_TICKET_CAP - TICKETS_BOUGHT, user
        );

        rips.requestRandomness(roundId);

        vm.warp(block.timestamp + VRF_EXPIRY - 1);

        vm.prank(user);
        vm.expectRevert(IRips.RoundNotExpired.selector);
        rips.refund(roundId, user);
    }

    function test_RevertWhen_TheRecipientHasAlreadyBeenRefunded() external {
        vm.warp(block.timestamp + DEFAULT_DURATION + 1);

        vm.prank(user);
        rips.refund(roundId, user);

        vm.prank(user);
        vm.expectRevert(IRips.AlreadyRefunded.selector);
        rips.refund(roundId, user);
    }

    function test_RevertWhen_TheRecipientHasNoTicketsInTheRound() external {
        vm.warp(block.timestamp + DEFAULT_DURATION + 1);

        address noTickets = makeAddr("noTickets");

        vm.prank(noTickets);
        vm.expectRevert(IRips.NoTicketsToRefund.selector);
        rips.refund(roundId, noTickets);
    }

    modifier givenTheStakeCurrencyIsNative() {
        _;
    }

    modifier whenTheRecipientHasTicketsInTheRound() {
        vm.warp(block.timestamp + DEFAULT_DURATION + 1);
        _;
    }

    function test_WhenTheRecipientHasTicketsInTheRound()
        external
        givenTheStakeCurrencyIsNative
        whenTheRecipientHasTicketsInTheRound
    {
        uint256 balanceBefore = user.balance;

        vm.expectEmit();
        emit IRips.RefundIssued(roundId, user, TICKETS_BOUGHT);

        vm.prank(user);
        rips.refund(roundId, user);

        assertEq(user.balance, balanceBefore + _expectedRefundAmount());
        assertTrue(rips.hasRefunded(roundId, user));
    }

    function test_WhenRecipientIsDifferentFromTheCaller()
        external
        givenTheStakeCurrencyIsNative
        whenTheRecipientHasTicketsInTheRound
    {
        address caller = makeAddr("caller");

        uint256 recipientBalanceBefore = user.balance;
        uint256 callerBalanceBefore = caller.balance;

        vm.prank(caller);
        rips.refund(roundId, user);

        assertEq(user.balance, recipientBalanceBefore + _expectedRefundAmount());
        assertEq(caller.balance, callerBalanceBefore);
    }

    modifier givenTheStakeCurrencyIsAnERC20Token() {
        _mintAndApprove(user, TICKETS_BOUGHT * DEFAULT_TICKET_COST);

        uint256 erc20StakeId = _createDefaultERC20Stake();

        vm.prank(user);
        rips.buyTickets(erc20StakeId, TICKETS_BOUGHT, user);

        roundId = rips.stakeIdToCurrentRoundId(erc20StakeId);

        vm.warp(block.timestamp + DEFAULT_DURATION + 1);
        _;
    }

    function test_WhenTheRecipientHasTicketsInTheRound_GivenERC20()
        external
        givenTheStakeCurrencyIsAnERC20Token
    {
        uint256 balanceBefore = erc20.balanceOf(user);

        vm.expectEmit();
        emit IRips.RefundIssued(roundId, user, TICKETS_BOUGHT);

        vm.prank(user);
        rips.refund(roundId, user);

        assertEq(erc20.balanceOf(user), balanceBefore + _expectedRefundAmount());
        assertTrue(rips.hasRefunded(roundId, user));
    }

    function test_WhenRecipientIsDifferentFromTheCaller_GivenERC20()
        external
        givenTheStakeCurrencyIsAnERC20Token
    {
        address caller = makeAddr("caller");

        uint256 recipientBalanceBefore = erc20.balanceOf(user);
        uint256 callerBalanceBefore = erc20.balanceOf(caller);

        vm.prank(caller);
        rips.refund(roundId, user);

        assertEq(erc20.balanceOf(user), recipientBalanceBefore + _expectedRefundAmount());
        assertEq(erc20.balanceOf(caller), callerBalanceBefore);
    }
}
