// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract Rips_SetProtocolFee {
    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        // it should revert.
    }

    modifier whenTheCallerIsTheOwner() {
        _;
    }

    function test_RevertWhen_TheNewFeeExceeds10000() external whenTheCallerIsTheOwner {
        // it should revert.
    }

    function test_WhenTheNewFeeIsAtMost10000() external whenTheCallerIsTheOwner {
        // it should update the protocol fee percent.
        // it should emit a {ProtocolFeeUpdated} event.
    }
}
