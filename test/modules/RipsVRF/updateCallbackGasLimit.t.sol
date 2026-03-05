// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract Rips_UpdateCallbackGasLimit is RipsTestBase {
    event CallbackGasLimitUpdated(uint32 newLimit);
    uint32 private constant NEW_GAS_LIMIT = 200_000;

    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        vm.prank(user);
        vm.expectRevert("Only callable by owner");
        rips.updateCallbackGasLimit(NEW_GAS_LIMIT);
    }

    modifier whenTheCallerIsTheOwner() {
        vm.prank(owner);
        _;
    }

    function test_WhenTheCallerIsTheOwner() external whenTheCallerIsTheOwner {
        vm.expectEmit();
        emit CallbackGasLimitUpdated(NEW_GAS_LIMIT);

        rips.updateCallbackGasLimit(NEW_GAS_LIMIT);
    }
}
