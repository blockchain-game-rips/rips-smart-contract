// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

// config: [[1,2],[6,8],[20,30,40,50]] ether
contract RipsMath_CalculatePrizeAmount is RipsTestBase {
    uint256 private stakeId;

    uint256 private constant PRIZE_1 = 1 ether;
    uint256 private constant PRIZE_2 = 2 ether;
    uint256 private constant PRIZE_3 = 6 ether;
    uint256 private constant PRIZE_4 = 8 ether;
    uint256 private constant PRIZE_5 = 20 ether;
    uint256 private constant PRIZE_6 = 30 ether;
    uint256 private constant PRIZE_7 = 40 ether;
    uint256 private constant PRIZE_8 = 50 ether;

    uint256 private constant TICKET_CAP = 8;
    uint256 private constant TICKET_COST = 157 ether / 8;

    function setUp() public override {
        super.setUp();

        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](3);
        tiers[0] = IRips.PrizeTier({prizeCount: 2, minPrize: PRIZE_1, maxPrize: PRIZE_2});
        tiers[1] = IRips.PrizeTier({prizeCount: 2, minPrize: PRIZE_3, maxPrize: PRIZE_4});
        tiers[2] = IRips.PrizeTier({prizeCount: 4, minPrize: PRIZE_5, maxPrize: PRIZE_8});

        vm.prank(owner);
        stakeId = rips.createStake(
            IRips.StakeConfig({
                prizeDistribution: tiers,
                ticketCap: TICKET_CAP,
                duration: 1 days,
                ticketCost: TICKET_COST
            })
        );
    }

    //TODO: simplify
    function test_ShouldNeverRevert(
        uint8 exponent,
        uint8 numTiersFuzz,
        uint128 prizePerTicket,
        uint256 duration,
        uint256 prizeNumber
    ) external {
        uint256 ticketCap = 1 << (exponent % 8);
        uint256 numTiers = bound(uint256(numTiersFuzz), 1, ticketCap);

        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](numTiers);

        uint256 remaining = ticketCap;

        for (uint256 i = 0; i < numTiers; i++) {
            uint256 prizeCount = (i == numTiers - 1) ? remaining : remaining / (numTiers - i);

            remaining -= prizeCount;

            tiers[i] = IRips.PrizeTier({
                prizeCount: prizeCount, minPrize: prizePerTicket, maxPrize: prizePerTicket
            });
        }

        // minPrize == maxPrize == prizePerTicket, so totalPrizePool == ticketCap * prizePerTicket exactly
        vm.prank(owner);
        uint256 newStakeId = rips.createStake(
            IRips.StakeConfig({
                prizeDistribution: tiers,
                ticketCap: ticketCap,
                duration: duration,
                ticketCost: prizePerTicket
            })
        );

        rips.exposed_calculatePrizeAmount(bound(prizeNumber, 1, ticketCap), newStakeId);
    }

    function test_WhenThePrizeNumberIsInTheFirstTier() external view {
        assertEq(rips.exposed_calculatePrizeAmount(1, stakeId), PRIZE_1);
        assertEq(rips.exposed_calculatePrizeAmount(2, stakeId), PRIZE_2);
    }

    function test_WhenThePrizeNumberIsInAMiddleTier() external view {
        assertEq(rips.exposed_calculatePrizeAmount(3, stakeId), PRIZE_3);
        assertEq(rips.exposed_calculatePrizeAmount(4, stakeId), PRIZE_4);
    }

    function test_WhenThePrizeNumberIsInTheLastTier() external view {
        assertEq(rips.exposed_calculatePrizeAmount(5, stakeId), PRIZE_5);
        assertEq(rips.exposed_calculatePrizeAmount(6, stakeId), PRIZE_6);
        assertEq(rips.exposed_calculatePrizeAmount(7, stakeId), PRIZE_7);
        assertEq(rips.exposed_calculatePrizeAmount(8, stakeId), PRIZE_8);
    }
}
