// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract Rips_ClaimPrizes {
    function test_RevertWhen_TheRoundIsNotFinalized() external {
        // it should revert.
    }

    modifier whenTheRoundIsFinalized() {
        _;
    }

    function test_RevertWhen_StartIndexIsOutOfBounds() external whenTheRoundIsFinalized {
        // it should revert.
    }

    modifier whenStartIndexIsValid() {
        _;
    }

    function test_WhenAllRangesInScopeAreAlreadyClaimed()
        external
        whenTheRoundIsFinalized
        whenStartIndexIsValid
    {
        // it should not transfer any ETH.
    }

    modifier whenThereAreUnclaimedRanges() {
        _;
    }

    function test_WhenThereAreUnclaimedRanges()
        external
        whenTheRoundIsFinalized
        whenStartIndexIsValid
        whenThereAreUnclaimedRanges
    {
        // it should mark processed ranges as claimed.
        // it should calculate correct prizes using the affine permutation.
    }

    function test_WhenProtocolFeeIsZero()
        external
        whenTheRoundIsFinalized
        whenStartIndexIsValid
        whenThereAreUnclaimedRanges
    {
        // it should transfer the full prize to the caller.
        // it should emit a {PrizesClaimed} event.
    }

    function test_WhenProtocolFeeIsGreaterThanZero()
        external
        whenTheRoundIsFinalized
        whenStartIndexIsValid
        whenThereAreUnclaimedRanges
    {
        // it should transfer the fee to the fee recipient.
        // it should transfer the remaining prize to the caller.
        // it should emit a {PrizesClaimed} event.
    }
}
