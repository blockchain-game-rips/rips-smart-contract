// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract Rips_UpdateVrfSubscriptionId is RipsTestBase {
    event VrfSubscriptionIdUpdated(uint256 newSubscriptionId);

    uint256 private constant NEW_SUBSCRIPTION_ID = 999;

    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        vm.prank(user);
        vm.expectRevert();
        rips.updateVrfSubscriptionId(NEW_SUBSCRIPTION_ID);
    }

    modifier whenTheCallerIsTheOwner() {
        vm.prank(owner);
        _;
    }

    function test_RevertWhen_TheNewSubscriptionIdIsZero() external whenTheCallerIsTheOwner {
        vm.expectRevert(IRips.ZeroSubscriptionId.selector);
        rips.updateVrfSubscriptionId(0);
    }

    function test_WhenTheNewSubscriptionIdIsNonZero() external whenTheCallerIsTheOwner {
        vm.expectEmit();
        emit VrfSubscriptionIdUpdated(NEW_SUBSCRIPTION_ID);

        rips.updateVrfSubscriptionId(NEW_SUBSCRIPTION_ID);

        assertEq(rips.vrfSubscriptionId(), NEW_SUBSCRIPTION_ID);
    }
}
