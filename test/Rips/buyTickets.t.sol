// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract Rips_BuyTickets {
    function test_RevertWhen_TheContractIsPaused() external {
        // it should revert.
    }

    function test_RevertWhen_RecipientIsZeroAddress() external {
        // it should revert.
    }

    function test_RevertWhen_TheStakeDoesNotExist() external {
        // it should revert.
    }

    function test_RevertWhen_TheActiveRoundHasExpiredAndTheStakeIsDeleted() external {
        // it should revert.
    }

    function test_WhenTheActiveRoundHasExpiredAndTheStakeIsNotDeleted() external {
        // it should create a new round.
        // it should emit a {RoundCreated} event.
    }

    function test_RevertWhen_TicketCountIsZero() external {
        // it should revert.
    }

    function test_RevertWhen_ThePaymentAmountIsIncorrect() external {
        // it should revert.
    }

    modifier whenRequestedTicketsAreFewerThanAvailable() {
        _;
    }

    function test_WhenRequestedTicketsAreFewerThanAvailable()
        external
        whenRequestedTicketsAreFewerThanAvailable
    {
        // it should update tickets sold count.
        // it should store ticket ranges for the recipient.
        // it should emit a {TicketsPurchased} event.
    }

    function test_WhenRecipientIsDifferentFromTheCaller()
        external
        whenRequestedTicketsAreFewerThanAvailable
    {
        // it should store ticket ranges for the recipient, not the caller.
    }

    function test_WhenTicketCountExceedsMAX_TICKETS_PER_RANGE()
        external
        whenRequestedTicketsAreFewerThanAvailable
    {
        // it should split into multiple ticket ranges.
    }

    modifier whenRequestedTicketsEqualTheRemainingCapacity() {
        _;
    }

    function test_WhenRequestedTicketsEqualTheRemainingCapacity()
        external
        whenRequestedTicketsEqualTheRemainingCapacity
    {
        // it should purchase all requested tickets.
        // it should set round status to SoldOut.
        // it should emit a {TicketsPurchased} event.
    }

    function test_GivenTheStakeIsNotDeleted()
        external
        whenRequestedTicketsEqualTheRemainingCapacity
    {
        // it should create a new round for the stake.
    }

    function test_GivenTheStakeIsDeleted() external whenRequestedTicketsEqualTheRemainingCapacity {
        // it should clear the active round mapping.
    }

    function test_WhenRequestedTicketsExceedAvailableTickets() external {
        // it should purchase only the available tickets.
        // it should set round status to SoldOut.
        // it should refund excess payment to the caller.
        // it should emit a {TicketsPurchased} event.
    }
}
