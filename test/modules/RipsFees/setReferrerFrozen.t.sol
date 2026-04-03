// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract Rips_SetReferrerFrozen is RipsTestBase {
    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        // it should revert.
        vm.prank(user);
        vm.expectRevert();
        rips.setReferrerFrozen(referrer, true);
    }

    function test_RevertWhen_TheReferrerIsTheZeroAddress() external {
        // it should revert.
        vm.prank(owner);
        vm.expectRevert(IRips.ZeroAddress.selector);
        rips.setReferrerFrozen(address(0), true);
    }

    function test_WhenTheCallerIsTheOwnerAndReferrerIsNotTheZeroAddress() external {
        // it should update the frozen status.
        // it should emit a {ReferrerFreezeUpdated} event.
        vm.startPrank(owner);

        vm.expectEmit();
        emit IRips.ReferrerFreezeUpdated(referrer, true);
        rips.setReferrerFrozen(referrer, true);

        assertEq(rips.isReferrerFrozen(referrer), true);

        vm.expectEmit();
        emit IRips.ReferrerFreezeUpdated(referrer, false);
        rips.setReferrerFrozen(referrer, false);

        assertEq(rips.isReferrerFrozen(referrer), false);

        vm.stopPrank();
    }
}
