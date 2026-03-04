// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract Rips_CreateStake {
    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        // it should revert.
    }

    modifier whenTheCallerIsTheOwner() {
        _;
    }

    function test_RevertWhen_TicketCapIsNotAPowerOfTwo() external whenTheCallerIsTheOwner {
        // it should revert.
    }

    modifier whenTicketCapIsAPowerOfTwo() {
        _;
    }

    function test_RevertWhen_PrizeDistributionIsEmpty()
        external
        whenTheCallerIsTheOwner
        whenTicketCapIsAPowerOfTwo
    {
        // it should revert.
    }

    modifier whenPrizeDistributionIsNotEmpty() {
        _;
    }

    function test_RevertWhen_ATierHasMinPrizeGreaterThanMaxPrize()
        external
        whenTheCallerIsTheOwner
        whenTicketCapIsAPowerOfTwo
        whenPrizeDistributionIsNotEmpty
    {
        // it should revert.
    }

    modifier whenAllTiersHaveValidPrizeRanges() {
        _;
    }

    function test_RevertWhen_TotalPrizeCountDoesNotEqualTicketCap()
        external
        whenTheCallerIsTheOwner
        whenTicketCapIsAPowerOfTwo
        whenPrizeDistributionIsNotEmpty
        whenAllTiersHaveValidPrizeRanges
    {
        // it should revert.
    }

    modifier whenTotalPrizeCountEqualsTicketCap() {
        _;
    }

    function test_RevertWhen_TotalPrizePoolDoesNotEqualTicketCapTimesTicketCost()
        external
        whenTheCallerIsTheOwner
        whenTicketCapIsAPowerOfTwo
        whenPrizeDistributionIsNotEmpty
        whenAllTiersHaveValidPrizeRanges
        whenTotalPrizeCountEqualsTicketCap
    {
        // it should revert.
    }

    function test_WhenTotalPrizePoolEqualsTicketCapTimesTicketCost()
        external
        whenTheCallerIsTheOwner
        whenTicketCapIsAPowerOfTwo
        whenPrizeDistributionIsNotEmpty
        whenAllTiersHaveValidPrizeRanges
        whenTotalPrizeCountEqualsTicketCap
    {
        // it should store the stake configuration.
        // it should create an initial round.
        // it should increment the next stake ID.
        // it should emit a {StakeCreated} event.
    }
}
