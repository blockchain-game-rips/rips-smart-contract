// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";

// 7-tier stake, ticketCap = 128, ticketCost = 1 ether
// Tiers ordered by highest prizeCount first to minimise linear search depth.
// Prize tiers (interpolated tiers, totalPool = 128 ether):
//   Tier 1: 50 prizes @ 0.1–0.5 ether   avg 0.3  = 15 ether
//   Tier 2: 34 prizes @ 0.3–0.7 ether   avg 0.5  = 17 ether
//   Tier 3: 20 prizes @ 0.5–1.5 ether   avg 1.0  = 20 ether
//   Tier 4: 12 prizes @ 1–3 ether       avg 2.0  = 24 ether
//   Tier 5:  8 prizes @ 2–4 ether       avg 3.0  = 24 ether
//   Tier 6:  3 prizes @ 4–8 ether       avg 6.0  = 18 ether
//   Tier 7:  1 prize  @ 10 ether        avg 10.0 = 10 ether
//                                            total = 128 ether
contract Rips_SevenTiers is RipsTestBase {
    uint256 private constant TICKET_CAP = 128;
    uint256 private constant TICKET_COST = 1 ether;

    uint256 private stakeId;
    uint256 private roundId;

    function setUp() public override {
        super.setUp();

        vrfCoordinator.fundSubscription(vrfSubscriptionId, 1000 ether);

        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](7);
        tiers[0] = IRips.PrizeTier({prizeCount: 50, minPrize: 0.1 ether, maxPrize: 0.5 ether});
        tiers[1] = IRips.PrizeTier({prizeCount: 34, minPrize: 0.3 ether, maxPrize: 0.7 ether});
        tiers[2] = IRips.PrizeTier({prizeCount: 20, minPrize: 0.5 ether, maxPrize: 1.5 ether});
        tiers[3] = IRips.PrizeTier({prizeCount: 12, minPrize: 1 ether, maxPrize: 3 ether});
        tiers[4] = IRips.PrizeTier({prizeCount: 8, minPrize: 2 ether, maxPrize: 4 ether});
        tiers[5] = IRips.PrizeTier({prizeCount: 3, minPrize: 4 ether, maxPrize: 8 ether});
        tiers[6] = IRips.PrizeTier({prizeCount: 1, minPrize: 10 ether, maxPrize: 10 ether});

        vm.prank(owner);
        stakeId = rips.createStake(
            IRips.Config({
                currency: address(0),
                tiers: tiers,
                ticketCap: TICKET_CAP,
                duration: DEFAULT_DURATION,
                ticketCost: TICKET_COST,
                feePercent: 0
            })
        );

        vm.deal(user, TICKET_CAP * TICKET_COST);
    }

    function _buyAllTickets() private {
        vm.prank(user);
        rips.buyTickets{value: TICKET_CAP * TICKET_COST}(stakeId, TICKET_CAP, user);
        roundId = rips.stakeIdToCurrentRoundId(stakeId);
    }

    function _finalizeRound() private {
        uint256 vrfRequestId = rips.requestRandomness(roundId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));
    }

    function test_ClaimPrizes_SevenTiers() external {
        _buyAllTickets();
        _finalizeRound();

        uint256 balanceBefore = user.balance;

        vm.prank(user);
        rips.claimPrizes(roundId, 0, 1, user, referrer);

        assertGt(user.balance, balanceBefore);

        IRips.TicketRange[] memory ranges = rips.getUserTickets(roundId, user);
        assertTrue(ranges[0].claimed);
    }

    function test_Refund_SevenTiers() external {
        uint256 ticketsToBuy = TICKET_CAP / 2;

        vm.prank(user);
        rips.buyTickets{value: ticketsToBuy * TICKET_COST}(stakeId, ticketsToBuy, user);
        roundId = rips.stakeIdToCurrentRoundId(stakeId);

        vm.warp(block.timestamp + DEFAULT_DURATION + 1);

        uint256 balanceBefore = user.balance;

        vm.prank(user);
        rips.refund(roundId, user);

        assertEq(user.balance, balanceBefore + ticketsToBuy * TICKET_COST);
    }
}
