// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract Rips_Refund {
    function test_RevertWhen_TheRoundDoesNotExist() external {
        // it should revert.
    }

    function test_RevertWhen_RecipientIsZeroAddress() external {
        // it should revert.
    }

    function test_RevertWhen_TheRoundIsNotExpired() external {
        // it should revert.
    }

    function test_RevertWhen_TheRecipientHasAlreadyBeenRefunded() external {
        // it should revert.
    }

    function test_RevertWhen_TheRecipientHasNoTicketsInTheRound() external {
        // it should revert.
    }

    modifier whenTheRecipientHasTicketsInTheRound() {
        _;
    }

    function test_WhenTheRecipientHasTicketsInTheRound()
        external
        whenTheRecipientHasTicketsInTheRound
    {
        // it should mark the recipient as refunded.
        // it should transfer the refund amount to the recipient.
        // it should emit a {RefundIssued} event.
    }

    function test_WhenRecipientIsDifferentFromTheCaller()
        external
        whenTheRecipientHasTicketsInTheRound
    {
        // it should transfer the refund to the recipient, not the caller.
    }
}
