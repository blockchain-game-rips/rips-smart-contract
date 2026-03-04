// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract Rips_UpdateCallbackGasLimit {
    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        // it should revert.
    }

    function test_WhenTheCallerIsTheOwner() external {
        // it should update the callback gas limit.
        // it should emit a {CallbackGasLimitUpdated} event.
    }
}
