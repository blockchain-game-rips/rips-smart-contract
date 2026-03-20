// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";

// 16-tier stake, ticketCap = 1024, ticketCost = 1 ether
// Equal 64 tickets per tier, linearly increasing prizes.
// avg_i = (2i+1)/16 ether, spread ±30%, totalPool = 1024 ether
contract Rips_SixteenTiers is RipsTestBase {
    uint256 private constant TICKET_CAP = 1024;
    uint256 private constant TICKET_COST = 1 ether;
    uint256 private constant TIER_COUNT = 16;
    uint256 private constant TICKETS_PER_TIER = TICKET_CAP / TIER_COUNT;

    uint128 private constant MN_UNIT = 43_750_000_000_000_000;
    uint128 private constant MX_UNIT = 81_250_000_000_000_000;

    uint256 private stakeId;
    uint256 private roundId;

    function setUp() public override {
        super.setUp();

        vrfCoordinator.fundSubscription(vrfSubscriptionId, 1000 ether);

        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](TIER_COUNT);

        for (uint256 i = 0; i < TIER_COUNT; i++) {
            uint128 k = uint128(2 * i + 1);

            tiers[i] = IRips.PrizeTier({
                prizeCount: uint64(TICKETS_PER_TIER),
                minPrize: k * MN_UNIT,
                maxPrize: k * MX_UNIT
            });
        }

        vm.prank(owner);
        stakeId = rips.createStake(
            IRips.StakeConfig({
                prizeDistribution: tiers,
                ticketCap: TICKET_CAP,
                duration: DEFAULT_DURATION,
                ticketCost: TICKET_COST
            })
        );

        roundId = rips.exposed_stakeToActiveRound(stakeId);

        vm.deal(user, TICKET_CAP * TICKET_COST);
    }

    function _buyAllTickets() private {
        vm.prank(user);
        rips.buyTickets{value: TICKET_CAP * TICKET_COST}(stakeId, TICKET_CAP, user);
    }

    function _finalizeRound() private {
        uint256 vrfRequestId = rips.requestRandomness(roundId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));
    }

    function test_ClaimPrizes_SixteenTiers() external {
        _buyAllTickets();
        _finalizeRound();

        uint256 balanceBefore = user.balance;

        vm.prank(user);
        rips.claimPrizes(roundId, 0, 2, user);

        assertGt(user.balance, balanceBefore);

        IRips.TicketRange[] memory ranges = rips.getUserTickets(roundId, user);
        assertTrue(ranges[0].claimed);
        assertTrue(ranges[1].claimed);
    }

    function test_Refund_SixteenTiers() external {
        uint256 ticketsToBuy = TICKET_CAP / 2;

        vm.prank(user);
        rips.buyTickets{value: ticketsToBuy * TICKET_COST}(stakeId, ticketsToBuy, user);

        vm.warp(block.timestamp + DEFAULT_DURATION + 1);

        uint256 balanceBefore = user.balance;

        vm.prank(user);
        rips.refund(roundId, user);

        assertEq(user.balance, balanceBefore + ticketsToBuy * TICKET_COST);
    }
}
