// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract RipsMath_PrizeForRankInTier is RipsTestBase {
    uint256 private stakeId;

    uint256 private constant SINGLE_WINNER_PRIZE = 1 ether;
    uint256 private constant RANGE_MIN_PRIZE = 0;
    uint256 private constant RANGE_MAX_PRIZE = 2 ether;

    function setUp() public override {
        super.setUp();

        // tier 0: 1 winner,  prize = 1 ether
        // tier 1: 3 winners, prizes from 0 to 2 ether
        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](2);
        tiers[0] = IRips.PrizeTier({
            winnersInTier: 1, minPrize: SINGLE_WINNER_PRIZE, maxPrize: SINGLE_WINNER_PRIZE
        });
        tiers[1] = IRips.PrizeTier({
            winnersInTier: 3, minPrize: RANGE_MIN_PRIZE, maxPrize: RANGE_MAX_PRIZE
        });

        vm.prank(owner);
        stakeId = rips.createStake(
            IRips.StakeConfig({
                prizeDistribution: tiers, ticketCap: 4, duration: 1 days, ticketCost: 1 ether
            })
        );
    }

    function test_WhenTheTierHasASingleWinner() external view {
        assertEq(rips.exposed_prizeForRankInTier(stakeId, 0, 1), SINGLE_WINNER_PRIZE);
    }

    modifier whenTheTierHasMultipleWinners() {
        _;
    }

    function test_WhenTheRankIsFirstInTheTier() external view whenTheTierHasMultipleWinners {
        assertEq(rips.exposed_prizeForRankInTier(stakeId, 1, 1), RANGE_MIN_PRIZE);
    }

    function test_WhenTheRankIsLastInTheTier() external view whenTheTierHasMultipleWinners {
        assertEq(rips.exposed_prizeForRankInTier(stakeId, 1, 3), RANGE_MAX_PRIZE);
    }

    function test_WhenTheRankIsInTheMiddleOfTheTier() external view whenTheTierHasMultipleWinners {
        // 3 winners, 0 to 2 ether: [0, 1, 2], rank 2 = 1 ether
        assertEq(rips.exposed_prizeForRankInTier(stakeId, 1, 2), 1 ether);
    }
}
