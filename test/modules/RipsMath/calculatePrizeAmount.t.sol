// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract RipsMath_CalculatePrizeAmount {
    function test_ShouldNeverRevert() external {
        // it should never revert.
    }

    function test_WhenThePrizeNumberIsInTheFirstTier() external {
        // it should return the prize for that position.
    }

    function test_WhenThePrizeNumberIsInTheLastTier() external {
        // it should return the prize for that position.
    }

    function test_WhenThePrizeNumberIsInAMiddleTier() external {
        // it should return the prize for that position.
    }

    modifier whenThePrizeNumberMatchesATier() {
        _;
    }

    function test_WhenTheTierHasASingleWinner() external whenThePrizeNumberMatchesATier {
        // it should return the min prize.
    }

    modifier whenTheTierHasMultipleWinners() {
        _;
    }

    function test_WhenThePrizeIsAtTheStartOfTheTier()
        external
        whenThePrizeNumberMatchesATier
        whenTheTierHasMultipleWinners
    {
        // it should return the min prize.
    }

    function test_WhenThePrizeIsAtTheEndOfTheTier()
        external
        whenThePrizeNumberMatchesATier
        whenTheTierHasMultipleWinners
    {
        // it should return the max prize.
    }

    function test_WhenThePrizeIsInTheMiddleOfTheTier()
        external
        whenThePrizeNumberMatchesATier
        whenTheTierHasMultipleWinners
    {
        // it should linearly interpolate between min and max prize.
    }
}
