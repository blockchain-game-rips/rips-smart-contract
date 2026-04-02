// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";

contract Rips_ClaimPrizes_Referrer is RipsTestBase {
    uint256 private constant START_INDEX = 0;
    uint256 private constant MAX_RANGES = 10;
    uint256 private constant BASE_FEE_PERCENT = 300; // 3%
    uint256 private constant TIER_1_FEE_PERCENT = 800; // 8%
    uint256 private constant TIER_2_FEE_PERCENT = 1500; // 15%
    uint256 private constant CUSTOM_FEE_PERCENT = 2000; // 20%
    uint128 private constant TIER_1_MIN_VOLUME = 1 ether; // reachable: DEFAULT_TICKET_CAP * DEFAULT_TICKET_COST = 4 ether
    uint128 private constant TIER_2_MIN_VOLUME = 10 ether; // not reachable in a single default round

    uint256 private stakeId;
    uint256 private roundId;

    function setUp() public override {
        super.setUp();

        vrfCoordinator.fundSubscription(vrfSubscriptionId, 100 ether);

        stakeId = _createDefaultStake();
        roundId = rips.exposed_stakeIdToCurrentRoundId(stakeId);

        vm.deal(user, 100 ether);
        vm.prank(user);
        rips.buyTickets{value: DEFAULT_TICKET_CAP * DEFAULT_TICKET_COST}(
            stakeId, DEFAULT_TICKET_CAP, user
        );

        uint256 vrfRequestId = rips.requestRandomness(roundId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));
    }

    function _totalPrize() private pure returns (uint256) {
        return DEFAULT_TICKET_CAP * DEFAULT_TICKET_COST;
    }

    function _protocolFee() private pure returns (uint256) {
        return (_totalPrize() * DEFAULT_FEE_PERCENT) / 10_000;
    }

    function _referrerFeeFrom(uint256 feePercent) private pure returns (uint256) {
        return (_protocolFee() * feePercent) / 10_000;
    }

    function _setBaseFee() private {
        vm.prank(owner);
        rips.setBaseFeePercent(uint16(BASE_FEE_PERCENT));
    }

    function _setTiers() private {
        IRips.ReferralTier[] memory tiers = new IRips.ReferralTier[](2);
        tiers[0] = IRips.ReferralTier({
            minVolume: TIER_1_MIN_VOLUME, feePercent: uint16(TIER_1_FEE_PERCENT)
        });
        tiers[1] = IRips.ReferralTier({
            minVolume: TIER_2_MIN_VOLUME, feePercent: uint16(TIER_2_FEE_PERCENT)
        });

        vm.prank(owner);
        rips.setReferralTiers(tiers);
    }

    function _claimAsUser() private {
        vm.prank(user);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user, referrer);
    }

    function _finalizeNewRound() private returns (uint256 newRoundId) {
        vm.deal(user, 100 ether);
        stakeId = _createDefaultStake();
        newRoundId = rips.exposed_stakeIdToCurrentRoundId(stakeId);

        vm.prank(user);
        rips.buyTickets{value: DEFAULT_TICKET_CAP * DEFAULT_TICKET_COST}(
            stakeId, DEFAULT_TICKET_CAP, user
        );

        uint256 vrfRequestId = rips.requestRandomness(newRoundId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));
    }

    function test_GivenReferrerIsZeroAddress() external {
        // it should send the full protocol fee to the fee recipient.
        uint256 feeRecipientBefore = owner.balance;

        vm.prank(user);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user, address(0));

        assertEq(owner.balance, feeRecipientBefore + _protocolFee());
    }

    function test_GivenReferrerHasACustomFeeSet() external {
        // it should apply customFeePercent directly to the protocol fee.
        // it should send the referrer fee to the referrer.
        // it should send the remaining protocol fee to the fee recipient.
        // it should emit a {ReferralFeePaid} event.
        // it should not update tier stats or emit {ReferrerStatsUpdated}.
        vm.prank(owner);
        rips.setReferrerCustomFee(referrer, uint16(CUSTOM_FEE_PERCENT));

        uint256 expectedReferrerFee = _referrerFeeFrom(CUSTOM_FEE_PERCENT);
        uint256 expectedProtocolFee = _protocolFee() - expectedReferrerFee;

        uint256 referrerBefore = referrer.balance;
        uint256 feeRecipientBefore = owner.balance;

        vm.expectEmit();
        emit IRips.ReferralFeePaid(roundId, referrer, expectedReferrerFee);

        vm.recordLogs();
        _claimAsUser();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(referrer.balance, referrerBefore + expectedReferrerFee);
        assertEq(owner.balance, feeRecipientBefore + expectedProtocolFee);

        bytes32 statsUpdatedSig = keccak256("ReferrerStatsUpdated(address,uint16,uint16)");
        for (uint256 i = 0; i < logs.length; i++) {
            assertNotEq(logs[i].topics[0], statsUpdatedSig);
        }

        IRips.ReferrerStats memory stats = rips.exposed_referrerToReferrerStats(referrer);
        assertEq(stats.currMonthVolume, 0);
    }

    function test_GivenNoReferralTiersAreConfiguredAndBaseFeeIsZero() external {
        // it should send the full protocol fee to the fee recipient.
        uint256 feeRecipientBefore = owner.balance;

        _claimAsUser();

        assertEq(owner.balance, feeRecipientBefore + _protocolFee());
        assertEq(referrer.balance, 0);
    }

    function test_GivenBaseFeeIsSetAndReferrerHasNoPriorActivity() external {
        // it should apply baseFeePercent to the protocol fee.
        // it should send the referrer fee to the referrer.
        // it should send the remaining protocol fee to the fee recipient.
        // it should emit a {ReferralFeePaid} event.
        _setBaseFee();

        uint256 expectedReferrerFee = _referrerFeeFrom(BASE_FEE_PERCENT);
        uint256 expectedProtocolFee = _protocolFee() - expectedReferrerFee;

        uint256 referrerBefore = referrer.balance;
        uint256 feeRecipientBefore = owner.balance;

        vm.expectEmit();
        emit IRips.ReferralFeePaid(roundId, referrer, expectedReferrerFee);

        _claimAsUser();

        assertEq(referrer.balance, referrerBefore + expectedReferrerFee);
        assertEq(owner.balance, feeRecipientBefore + expectedProtocolFee);
    }

    modifier givenReferralTiersAreConfiguredAndReferrerHasNoCustomFee() {
        _setBaseFee();
        _setTiers();
        _;
    }

    function test_WhenReferrerHasNoPriorActivity()
        external
        givenReferralTiersAreConfiguredAndReferrerHasNoCustomFee
    {
        // it should accumulate currMonthVolume.
        // it should apply baseFeePercent as the floor for the active fee.
        uint256 expectedReferrerFee = _referrerFeeFrom(BASE_FEE_PERCENT);
        uint256 referrerBefore = referrer.balance;

        _claimAsUser();

        IRips.ReferrerStats memory stats = rips.exposed_referrerToReferrerStats(referrer);
        assertEq(stats.currMonthVolume, _totalPrize());
        assertEq(referrer.balance, referrerBefore + expectedReferrerFee);
    }

    function test_WhenReferrersPreviousMonthVolumeReachedATierThreshold()
        external
        givenReferralTiersAreConfiguredAndReferrerHasNoCustomFee
    {
        // it should apply activeFeePercent to the protocol fee.
        // it should send the referrer fee to the referrer.
        // it should send the remaining protocol fee to the fee recipient.
        // it should emit a {ReferralFeePaid} event.

        // First month: accumulate enough volume to reach tier 1
        _claimAsUser();

        IRips.ReferrerStats memory statsAfterFirstClaim =
            rips.exposed_referrerToReferrerStats(referrer);
        assertEq(statsAfterFirstClaim.nextFeePercent, TIER_1_FEE_PERCENT);

        // Advance to next month and claim again — activeFeePercent should now be TIER_1_FEE_PERCENT
        vm.warp(block.timestamp + 31 days);

        uint256 newRoundId = _finalizeNewRound();

        uint256 expectedReferrerFee = _referrerFeeFrom(TIER_1_FEE_PERCENT);
        uint256 expectedProtocolFee = _protocolFee() - expectedReferrerFee;

        uint256 referrerBefore = referrer.balance;
        uint256 feeRecipientBefore = owner.balance;

        vm.expectEmit();
        emit IRips.ReferralFeePaid(newRoundId, referrer, expectedReferrerFee);

        vm.prank(user);
        rips.claimPrizes(newRoundId, START_INDEX, MAX_RANGES, user, referrer);

        assertEq(referrer.balance, referrerBefore + expectedReferrerFee);
        assertEq(owner.balance, feeRecipientBefore + expectedProtocolFee);
    }

    function test_WhenActiveFeePercentIsBelowBaseFeePercent()
        external
        givenReferralTiersAreConfiguredAndReferrerHasNoCustomFee
    {
        // it should apply baseFeePercent instead.

        // First month: no volume, so nextFeePercent stays 0
        // Second month: activeFeePercent = 0, which is below baseFeePercent
        vm.warp(block.timestamp + 31 days);

        uint256 newRoundId = _finalizeNewRound();
        uint256 expectedReferrerFee = _referrerFeeFrom(BASE_FEE_PERCENT);

        uint256 referrerBefore = referrer.balance;

        vm.prank(user);
        rips.claimPrizes(newRoundId, START_INDEX, MAX_RANGES, user, referrer);

        assertEq(referrer.balance, referrerBefore + expectedReferrerFee);
    }

    function test_WhenReferrersCurrentMonthVolumeCrossesATierThreshold()
        external
        givenReferralTiersAreConfiguredAndReferrerHasNoCustomFee
    {
        // it should update nextFeePercent.
        // it should emit a {ReferrerStatsUpdated} event.
        vm.recordLogs();
        _claimAsUser();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        IRips.ReferrerStats memory stats = rips.exposed_referrerToReferrerStats(referrer);
        assertEq(stats.nextFeePercent, TIER_1_FEE_PERCENT);

        bytes32 statsUpdatedSig = keccak256("ReferrerStatsUpdated(address,uint16,uint16)");
        bool found = false;
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == statsUpdatedSig) {
                found = true;
                break;
            }
        }
        assertTrue(found);
    }

    function test_WhenReferrersCurrentMonthVolumeCrossesMultipleTierThresholdsInOneClaim()
        external
        givenReferralTiersAreConfiguredAndReferrerHasNoCustomFee
    {
        // it should apply the highest reached tier to nextFeePercent.

        // Create a stake with enough ticket cap to exceed TIER_2_MIN_VOLUME in one round
        uint256 largeTicketCap = 64;
        uint256 largeTicketCost = 1 ether;

        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: uint64(largeTicketCap),
            minPrize: uint128(largeTicketCost),
            maxPrize: uint128(largeTicketCost)
        });

        vm.prank(owner);
        uint256 largeStakeId = rips.createStake(
            IRips.Config({
                currency: address(0),
                prizeDistribution: tiers,
                ticketCap: largeTicketCap,
                duration: DEFAULT_DURATION,
                ticketCost: largeTicketCost,
                feePercent: DEFAULT_FEE_PERCENT
            })
        );

        uint256 largeRoundId = rips.exposed_stakeIdToCurrentRoundId(largeStakeId);

        vm.deal(user, largeTicketCap * largeTicketCost);
        vm.prank(user);
        rips.buyTickets{value: largeTicketCap * largeTicketCost}(largeStakeId, largeTicketCap, user);

        uint256 vrfRequestId = rips.requestRandomness(largeRoundId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));

        vm.prank(user);
        rips.claimPrizes(largeRoundId, START_INDEX, MAX_RANGES, user, referrer);

        IRips.ReferrerStats memory stats = rips.exposed_referrerToReferrerStats(referrer);
        assertEq(stats.nextFeePercent, TIER_2_FEE_PERCENT);
    }

    function test_WhenANewMonthStartsAfterAnInactiveMonthGap()
        external
        givenReferralTiersAreConfiguredAndReferrerHasNoCustomFee
    {
        // it should reset activeFeePercent to zero.
        // it should reset currMonthVolume.

        // Month 1: claim to set nextFeePercent
        _claimAsUser();

        // Skip 2 months (gap month)
        vm.warp(block.timestamp + 62 days);

        uint256 newRoundId = _finalizeNewRound();

        vm.prank(user);
        rips.claimPrizes(newRoundId, START_INDEX, MAX_RANGES, user, referrer);

        IRips.ReferrerStats memory stats = rips.exposed_referrerToReferrerStats(referrer);
        assertEq(stats.activeFeePercent, 0);
        assertEq(stats.currMonthVolume, _totalPrize());
    }

    function test_WhenANewMonthStartsAfterAConsecutiveActiveMonth()
        external
        givenReferralTiersAreConfiguredAndReferrerHasNoCustomFee
    {
        // it should promote nextFeePercent to activeFeePercent.
        // it should reset currMonthVolume.

        // Month 1: claim to earn nextFeePercent = TIER_1_FEE_PERCENT
        _claimAsUser();

        // Advance exactly one month
        vm.warp(block.timestamp + 31 days);

        uint256 newRoundId = _finalizeNewRound();

        vm.prank(user);
        rips.claimPrizes(newRoundId, START_INDEX, MAX_RANGES, user, referrer);

        IRips.ReferrerStats memory stats = rips.exposed_referrerToReferrerStats(referrer);
        assertEq(stats.activeFeePercent, TIER_1_FEE_PERCENT);
        assertEq(stats.currMonthVolume, _totalPrize());
    }
}
