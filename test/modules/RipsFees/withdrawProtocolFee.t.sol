// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract Rips_WithdrawProtocolFee is RipsTestBase {
    uint16 private constant FEE_PERCENT = 500;
    uint256 private constant PRIZE_PER_TICKET = 0.95 ether;

    uint256 private roundId;

    function setUp() public override {
        super.setUp();

        vrfCoordinator.fundSubscription(vrfSubscriptionId, 100 ether);

        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: uint64(DEFAULT_TICKET_CAP),
            minPrize: uint128(PRIZE_PER_TICKET),
            maxPrize: uint128(PRIZE_PER_TICKET)
        });

        vm.prank(owner);
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

        vm.deal(user, DEFAULT_TICKET_CAP * DEFAULT_TICKET_COST);
        vm.prank(user);
        rips.buyTickets{value: DEFAULT_TICKET_CAP * DEFAULT_TICKET_COST}(
            stakeId, DEFAULT_TICKET_CAP, user
        );

        roundId = rips.stakeIdToCurrentRoundId(stakeId);
        uint256 vrfRequestId = rips.requestRandomness(roundId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));

        vm.prank(user);
        rips.claimPrizes(roundId, 0, 10, user, address(0));
    }

    function _protocolFee() private pure returns (uint256) {
        return DEFAULT_TICKET_CAP * DEFAULT_TICKET_COST * FEE_PERCENT / 10_000;
    }

    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        // it should revert.
        vm.prank(user);
        vm.expectRevert();
        rips.withdrawProtocolFee(address(0));
    }

    function test_RevertWhen_ThereIsNoAccruedFeeForTheCurrency() external {
        // it should revert.
        vm.prank(owner);
        vm.expectRevert(IRips.NothingToWithdraw.selector);
        rips.withdrawProtocolFee(address(erc20));
    }

    function test_WhenThereIsAccruedFeeForTheCurrency() external {
        // it should reset the accrued fee to zero.
        // it should transfer the fee to the fee recipient.
        // it should emit a {ProtocolFeeWithdrawn} event.
        uint256 feeRecipientBalanceBefore = owner.balance;

        vm.expectEmit();
        emit IRips.ProtocolFeeWithdrawn(owner, address(0), _protocolFee());

        vm.prank(owner);
        rips.withdrawProtocolFee(address(0));

        assertEq(rips.protocolFeeAccrued(address(0)), 0);
        assertEq(owner.balance, feeRecipientBalanceBefore + _protocolFee());
    }
}
