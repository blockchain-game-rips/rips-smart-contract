// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract Rips_Pause is RipsTestBase {
    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        vm.prank(user);
        vm.expectRevert();
        rips.pause();
    }

    function test_WhenTheCallerIsTheOwner() external {
        vm.prank(owner);
        rips.pause();

        assertTrue(rips.paused());
    }
}
