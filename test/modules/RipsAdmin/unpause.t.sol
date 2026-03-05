// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract Rips_Unpause is RipsTestBase {
    function setUp() public override {
        super.setUp();

        vm.prank(owner);
        rips.pause();
    }

    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        vm.prank(user);
        vm.expectRevert();
        rips.unpause();
    }

    function test_WhenTheCallerIsTheOwner() external {
        vm.prank(owner);
        rips.unpause();

        assertFalse(rips.paused());
    }
}
