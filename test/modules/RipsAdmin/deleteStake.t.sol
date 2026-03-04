// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

contract Rips_DeleteStake {
    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        // it should revert.
    }

    modifier whenTheCallerIsTheOwner() {
        _;
    }

    function test_RevertWhen_TheStakeIsAlreadyDeleted() external whenTheCallerIsTheOwner {
        // it should revert.
    }

    function test_WhenTheStakeIsNotDeleted() external whenTheCallerIsTheOwner {
        // it should mark the stake as deleted.
        // it should emit a {StakeDeleted} event.
    }
}
