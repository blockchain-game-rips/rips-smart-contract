// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract Rips_SeizeReferrerFee is RipsTestBase {
    uint16 private constant FEE_PERCENT = 500;
    uint16 private constant REFERRER_FEE_PERCENT = 2000;
    uint256 private constant PRIZE_PER_TICKET = 0.95 ether;

    function setUp() public override {
        super.setUp();

        vrfCoordinator.fundSubscription(vrfSubscriptionId, 100 ether);

        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: uint64(DEFAULT_TICKET_CAP),
            minPrize: uint128(PRIZE_PER_TICKET),
            maxPrize: uint128(PRIZE_PER_TICKET)
        });

        vm.startPrank(owner);
        uint256 stakeId = rips.createStake(
            IRips.Config({
                currency: address(0),
                tiers: tiers,
                ticketCap: DEFAULT_TICKET_CAP,
                duration: DEFAULT_DURATION,
                ticketCost: DEFAULT_TICKET_COST,
                feePercent: FEE_PERCENT
            })
        );
        rips.setReferrerCustomFee(referrer, REFERRER_FEE_PERCENT);
        vm.stopPrank();

        vm.deal(user, DEFAULT_TICKET_CAP * DEFAULT_TICKET_COST);
        vm.prank(user);
        rips.buyTickets{value: DEFAULT_TICKET_CAP * DEFAULT_TICKET_COST}(
            stakeId, DEFAULT_TICKET_CAP, user
        );

        uint256 roundId = rips.stakeIdToCurrentRoundId(stakeId);
        uint256 vrfRequestId = rips.requestRandomness(roundId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));

        vm.prank(user);
        rips.claimPrizes(roundId, 0, 10, user, referrer);
    }

    function _protocolFee() private pure returns (uint256) {
        return DEFAULT_TICKET_CAP * DEFAULT_TICKET_COST * FEE_PERCENT / 10_000;
    }

    function _referrerFee() private pure returns (uint256) {
        return _protocolFee() * REFERRER_FEE_PERCENT / 10_000;
    }

    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        // it should revert.
        vm.prank(user);
        vm.expectRevert();
        rips.seizeReferrerFee(referrer, address(0));
    }

    function test_RevertWhen_TheReferrerIsTheZeroAddress() external {
        // it should revert.
        vm.prank(owner);
        vm.expectRevert(IRips.ZeroAddress.selector);
        rips.seizeReferrerFee(address(0), address(0));
    }

    function test_RevertWhen_ThereIsNoAccruedFeeForTheReferrerAndCurrency() external {
        // it should revert.
        address otherReferrer = makeAddr("otherReferrer");
        vm.prank(owner);
        vm.expectRevert(IRips.NothingToWithdraw.selector);
        rips.seizeReferrerFee(otherReferrer, address(0));
    }

    function test_WhenThereIsAccruedFeeForTheReferrerAndCurrency() external {
        // it should reset the accrued fee to zero.
        // it should transfer the fee to the fee recipient.
        // it should emit a {ReferrerFeeSeized} event.
        uint256 feeRecipientBalanceBefore = owner.balance;

        vm.expectEmit();
        emit IRips.ReferrerFeeSeized(referrer, address(0), _referrerFee());

        vm.prank(owner);
        rips.seizeReferrerFee(referrer, address(0));

        assertEq(rips.referrerFeeAccrued(referrer, address(0)), 0);
        assertEq(owner.balance, feeRecipientBalanceBefore + _referrerFee());
    }
}
