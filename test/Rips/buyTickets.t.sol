// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract Rips_BuyTickets {
    function test_RevertWhen_TheContractIsPaused() external {
        // it should revert.
    }

    modifier whenTheContractIsNotPaused() {
        _;
    }

    function test_RevertWhen_TheStakeDoesNotExist() external whenTheContractIsNotPaused {
        // it should revert.
    }

    modifier whenTheStakeExists() {
        _;
    }

    modifier whenTheActiveRoundHasExpired() {
        _;
    }

    function test_RevertWhen_TheStakeIsDeleted()
        external
        whenTheContractIsNotPaused
        whenTheStakeExists
        whenTheActiveRoundHasExpired
    {
        // it should revert.
    }

    function test_WhenTheStakeIsNotDeleted()
        external
        whenTheContractIsNotPaused
        whenTheStakeExists
        whenTheActiveRoundHasExpired
    {
        // it should create a new round.
        // it should emit a {RoundCreated} event.
    }

    modifier whenTheActiveRoundHasNotExpired() {
        _;
    }

    function test_RevertWhen_TicketCountIsZero()
        external
        whenTheContractIsNotPaused
        whenTheStakeExists
        whenTheActiveRoundHasNotExpired
    {
        // it should revert.
    }

    modifier whenTicketCountIsGreaterThanZero() {
        _;
    }

    function test_RevertWhen_ThePaymentAmountIsIncorrect()
        external
        whenTheContractIsNotPaused
        whenTheStakeExists
        whenTheActiveRoundHasNotExpired
        whenTicketCountIsGreaterThanZero
    {
        // it should revert.
    }

    modifier whenThePaymentAmountIsCorrect() {
        _;
    }

    modifier whenRequestedTicketsAreFewerThanAvailable() {
        _;
    }

    function test_WhenRequestedTicketsAreFewerThanAvailable()
        external
        whenTheContractIsNotPaused
        whenTheStakeExists
        whenTheActiveRoundHasNotExpired
        whenTicketCountIsGreaterThanZero
        whenThePaymentAmountIsCorrect
        whenRequestedTicketsAreFewerThanAvailable
    {
        // it should update tickets sold count.
        // it should store ticket ranges for the buyer.
        // it should emit a {TicketsPurchased} event.
    }

    function test_WhenTicketCountExceedsMAX_TICKETS_PER_RANGE()
        external
        whenTheContractIsNotPaused
        whenTheStakeExists
        whenTheActiveRoundHasNotExpired
        whenTicketCountIsGreaterThanZero
        whenThePaymentAmountIsCorrect
        whenRequestedTicketsAreFewerThanAvailable
    {
        // it should split into multiple ticket ranges.
    }

    modifier whenRequestedTicketsEqualTheRemainingCapacity() {
        _;
    }

    function test_WhenRequestedTicketsEqualTheRemainingCapacity()
        external
        whenTheContractIsNotPaused
        whenTheStakeExists
        whenTheActiveRoundHasNotExpired
        whenTicketCountIsGreaterThanZero
        whenThePaymentAmountIsCorrect
        whenRequestedTicketsEqualTheRemainingCapacity
    {
        // it should purchase all requested tickets.
        // it should set round status to SoldOut.
        // it should emit a {TicketsPurchased} event.
    }

    function test_GivenTheStakeIsNotDeleted()
        external
        whenTheContractIsNotPaused
        whenTheStakeExists
        whenTheActiveRoundHasNotExpired
        whenTicketCountIsGreaterThanZero
        whenThePaymentAmountIsCorrect
        whenRequestedTicketsEqualTheRemainingCapacity
    {
        // it should create a new round for the stake.
    }

    function test_GivenTheStakeIsDeleted()
        external
        whenTheContractIsNotPaused
        whenTheStakeExists
        whenTheActiveRoundHasNotExpired
        whenTicketCountIsGreaterThanZero
        whenThePaymentAmountIsCorrect
        whenRequestedTicketsEqualTheRemainingCapacity
    {
        // it should clear the active round mapping.
    }

    function test_WhenRequestedTicketsExceedAvailableTickets()
        external
        whenTheContractIsNotPaused
        whenTheStakeExists
        whenTheActiveRoundHasNotExpired
        whenTicketCountIsGreaterThanZero
        whenThePaymentAmountIsCorrect
    {
        // it should purchase only the available tickets.
        // it should set round status to SoldOut.
        // it should refund excess payment to the buyer.
        // it should emit a {TicketsPurchased} event.
    }
}
