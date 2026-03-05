// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract Rips_Refund {
    function test_RevertWhen_TheRoundDoesNotExist() external {
        // it should revert.
    }

    modifier whenTheRoundExists() {
        _;
    }

    function test_RevertWhen_RecipientIsZeroAddress() external whenTheRoundExists {
        // it should revert.
    }

    function test_RevertWhen_TheRoundIsNotExpired() external whenTheRoundExists {
        // it should revert.
    }

    modifier whenTheRoundIsExpired() {
        _;
    }

    function test_RevertWhen_TheRecipientHasAlreadyBeenRefunded()
        external
        whenTheRoundExists
        whenTheRoundIsExpired
    {
        // it should revert.
    }

    modifier whenTheRecipientHasNotBeenRefunded() {
        _;
    }

    function test_RevertWhen_TheRecipientHasNoTicketsInTheRound()
        external
        whenTheRoundExists
        whenTheRoundIsExpired
        whenTheRecipientHasNotBeenRefunded
    {
        // it should revert.
    }

    modifier whenTheRecipientHasTicketsInTheRound() {
        _;
    }

    function test_WhenTheRecipientHasTicketsInTheRound()
        external
        whenTheRoundExists
        whenTheRoundIsExpired
        whenTheRecipientHasNotBeenRefunded
        whenTheRecipientHasTicketsInTheRound
    {
        // it should mark the recipient as refunded.
        // it should transfer the refund amount to the recipient.
        // it should emit a {RefundIssued} event.
    }

    function test_WhenRecipientIsDifferentFromTheCaller()
        external
        whenTheRoundExists
        whenTheRoundIsExpired
        whenTheRecipientHasNotBeenRefunded
        whenTheRecipientHasTicketsInTheRound
    {
        // it should transfer the refund to the recipient, not the caller.
    }

    function test_RevertWhen_TheCallerHasAlreadyBeenRefunded()
        external
        whenTheRoundExists
        whenTheRoundIsExpired
    {
        // it should revert.
    }

    modifier whenTheCallerHasNotBeenRefunded() {
        _;
    }

    function test_RevertWhen_TheCallerHasNoTicketsInTheRound()
        external
        whenTheRoundExists
        whenTheRoundIsExpired
        whenTheCallerHasNotBeenRefunded
    {
        // it should revert.
    }

    function test_WhenTheCallerHasTicketsInTheRound()
        external
        whenTheRoundExists
        whenTheRoundIsExpired
        whenTheCallerHasNotBeenRefunded
    {
        // it should mark the caller as refunded.
        // it should transfer the refund amount.
        // it should emit a {RefundIssued} event.
    }
}
