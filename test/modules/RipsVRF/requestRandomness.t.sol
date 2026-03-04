// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract Rips_RequestRandomness {
    function test_RevertWhen_TheRoundIsNotSoldOut() external {
        // it should revert.
    }

    function test_WhenTheRoundIsSoldOut() external {
        // it should request random words from Chainlink VRF.
        // it should set round status to VRFRequested.
        // it should map the VRF request ID to the round ID.
        // it should emit a {RandomnessRequested} event.
    }
}
