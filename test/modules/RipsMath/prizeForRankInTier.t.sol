// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract RipsMath_PrizeForRankInTier is RipsTestBase {
    uint256 private stakeId;

    uint256 private constant SINGLE_PRIZE = 1 ether;
    uint256 private constant RANGE_MIN_PRIZE = 0;
    uint256 private constant RANGE_MAX_PRIZE = 2 ether;

    function setUp() public override {
        super.setUp();

        // tier 0: 1 prize,  prize = 1 ether
        // tier 1: 3 prizes, prizes from 0 to 2 ether
        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](2);
        tiers[0] = IRips.PrizeTier({prizeCount: 1, minPrize: SINGLE_PRIZE, maxPrize: SINGLE_PRIZE});
        tiers[1] =
            IRips.PrizeTier({prizeCount: 3, minPrize: RANGE_MIN_PRIZE, maxPrize: RANGE_MAX_PRIZE});

        vm.prank(owner);
        stakeId = rips.createStake(
            IRips.StakeConfig({
                prizeDistribution: tiers, ticketCap: 4, duration: 1 days, ticketCost: 1 ether
            })
        );
    }

    function test_WhenTheTierHasASinglePrize() external view {
        assertEq(rips.exposed_prizeForRankInTier(stakeId, 0, 1), SINGLE_PRIZE);
    }

    modifier whenTheTierHasMultiplePrizes() {
        _;
    }

    function test_WhenTheRankIsFirstInTheTier() external view whenTheTierHasMultiplePrizes {
        assertEq(rips.exposed_prizeForRankInTier(stakeId, 1, 1), RANGE_MIN_PRIZE);
    }

    function test_WhenTheRankIsLastInTheTier() external view whenTheTierHasMultiplePrizes {
        assertEq(rips.exposed_prizeForRankInTier(stakeId, 1, 3), RANGE_MAX_PRIZE);
    }

    function test_WhenTheRankIsInTheMiddleOfTheTier() external view whenTheTierHasMultiplePrizes {
        // 3 prizes, 0 to 2 ether: [0, 1, 2], rank 2 = 1 ether
        assertEq(rips.exposed_prizeForRankInTier(stakeId, 1, 2), 1 ether);
    }
}
