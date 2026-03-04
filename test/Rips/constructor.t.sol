// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract Rips_Constructor {
    function test_RevertWhen_InitialOwnerIsZeroAddress() external {
        // it should revert.
    }

    function test_WhenInitialOwnerIsNotZeroAddress() external {
        // it should transfer ownership to initial owner.
        // it should set fee recipient to initial owner.
        // it should set protocol fee to initial fee percent.
    }
}
