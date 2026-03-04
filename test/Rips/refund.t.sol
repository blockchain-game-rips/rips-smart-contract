// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract Rips_Refund {
    function test_RevertWhen_TheRoundDoesNotExist() external {
        // it should revert.
    }

    modifier whenTheRoundExists() {
        _;
    }

    function test_RevertWhen_TheRoundIsNotExpired() external whenTheRoundExists {
        // it should revert.
    }

    modifier whenTheRoundIsExpired() {
        _;
    }

    function test_RevertWhen_TheCallerHasAlreadyBeenRefunded() external whenTheRoundExists whenTheRoundIsExpired {
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
