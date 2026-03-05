// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract Rips_FulfillRandomWords {
    function test_WhenCalledByTheVRFCoordinator() external {
        // it should derive a coprime value from the random word.
        // it should set randomB from the hash of the random word modulo ticket cap.
        // it should set round status to Finalized.
        // it should emit a {RoundFinalized} event.
    }
}
