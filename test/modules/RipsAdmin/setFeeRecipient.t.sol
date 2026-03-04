// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract Rips_SetFeeRecipient {
    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        // it should revert.
    }

    modifier whenTheCallerIsTheOwner() {
        _;
    }

    function test_RevertWhen_TheNewRecipientIsTheZeroAddress() external whenTheCallerIsTheOwner {
        // it should revert.
    }

    function test_WhenTheNewRecipientIsNotTheZeroAddress() external whenTheCallerIsTheOwner {
        // it should update the fee recipient.
        // it should emit a {FeeRecipientUpdated} event.
    }
}
