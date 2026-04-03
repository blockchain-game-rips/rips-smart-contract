// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";

contract Rips_ClaimPrizes_Referrer is RipsTestBase {
    uint256 private constant START_INDEX = 0;
    uint256 private constant MAX_RANGES = 10;
    uint16 private constant PROTOCOL_FEE_PERCENT = 500; // 5%
    uint256 private constant BASE_FEE_PERCENT = 300; // 3%
    uint256 private constant CUSTOM_FEE_PERCENT = 2000; // 20%
    uint256 private constant PRIZE_PER_TICKET =
        DEFAULT_TICKET_COST * (10000 - PROTOCOL_FEE_PERCENT) / 10000;

    uint256 private stakeId;
    uint256 private roundId;

    function setUp() public override {
        super.setUp();

        vrfCoordinator.fundSubscription(vrfSubscriptionId, 100 ether);

        stakeId = _createFeeStake();

        vm.deal(user, 100 ether);
        vm.prank(user);
        rips.buyTickets{value: DEFAULT_TICKET_CAP * DEFAULT_TICKET_COST}(
            stakeId, DEFAULT_TICKET_CAP, user
        );

        roundId = rips.stakeIdToCurrentRoundId(stakeId);
        uint256 vrfRequestId = rips.requestRandomness(roundId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));
    }

    function _createFeeStake() private returns (uint256) {
        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: uint64(DEFAULT_TICKET_CAP),
            minPrize: uint128(PRIZE_PER_TICKET),
            maxPrize: uint128(PRIZE_PER_TICKET)
        });

        vm.prank(owner);
        return rips.createStake(
            IRips.Config({
                currency: address(0),
                tiers: tiers,
                ticketCap: DEFAULT_TICKET_CAP,
                duration: DEFAULT_DURATION,
                ticketCost: DEFAULT_TICKET_COST,
                feePercent: PROTOCOL_FEE_PERCENT
            })
        );
    }

    function _ticketRevenue() private pure returns (uint256) {
        return DEFAULT_TICKET_CAP * DEFAULT_TICKET_COST;
    }

    function _protocolFee() private pure returns (uint256) {
        return _ticketRevenue() * PROTOCOL_FEE_PERCENT / 10_000;
    }

    function _referrerFeeFrom(uint256 feePercent) private pure returns (uint256) {
        return _protocolFee() * feePercent / 10_000;
    }

    function _claim() private {
        vm.prank(user);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user, referrer);
    }

    function test_GivenReferrerIsZeroAddress() external {
        uint256 feeRecipientBefore = owner.balance;

        vm.prank(user);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user, address(0));

        assertEq(owner.balance, feeRecipientBefore + _protocolFee());
        assertEq(referrer.balance, 0);
    }

    function test_GivenNoReferralTiersAreConfiguredAndBaseFeeIsZero() external {
        uint256 feeRecipientBefore = owner.balance;

        _claim();

        assertEq(owner.balance, feeRecipientBefore + _protocolFee());
        assertEq(referrer.balance, 0);
    }

    function test_GivenReferrerHasACustomFeeSet() external {
        vm.prank(owner);
        rips.setReferrerCustomFee(referrer, uint16(CUSTOM_FEE_PERCENT));

        uint256 expectedReferrerFee = _referrerFeeFrom(CUSTOM_FEE_PERCENT);

        uint256 referrerBefore = referrer.balance;
        uint256 feeRecipientBefore = owner.balance;

        vm.expectEmit();
        emit IRips.ReferralFeePaid(roundId, referrer, expectedReferrerFee);

        _claim();

        assertEq(referrer.balance, referrerBefore + expectedReferrerFee);
        assertEq(owner.balance, feeRecipientBefore + _protocolFee() - expectedReferrerFee);
    }

    function test_GivenBaseFeeIsSetAndReferrerHasNoPriorActivity() external {
        vm.prank(owner);
        rips.setBaseFeePercent(uint16(BASE_FEE_PERCENT));

        uint256 expectedReferrerFee = _referrerFeeFrom(BASE_FEE_PERCENT);

        uint256 referrerBefore = referrer.balance;
        uint256 feeRecipientBefore = owner.balance;

        vm.expectEmit();
        emit IRips.ReferralFeePaid(roundId, referrer, expectedReferrerFee);

        _claim();

        assertEq(referrer.balance, referrerBefore + expectedReferrerFee);
        assertEq(owner.balance, feeRecipientBefore + _protocolFee() - expectedReferrerFee);
    }
}
