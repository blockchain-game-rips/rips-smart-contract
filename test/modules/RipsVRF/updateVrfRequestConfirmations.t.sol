// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract Rips_UpdateVrfRequestConfirmations is RipsTestBase {
    event VrfRequestConfirmationsUpdated(uint16 newConfirmations);

    uint16 private constant NEW_CONFIRMATIONS = 5;

    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        vm.prank(user);
        vm.expectRevert();
        rips.updateVrfRequestConfirmations(NEW_CONFIRMATIONS);
    }

    modifier whenTheCallerIsTheOwner() {
        vm.prank(owner);
        _;
    }

    function test_WhenTheCallerIsTheOwner() external whenTheCallerIsTheOwner {
        vm.expectEmit();
        emit VrfRequestConfirmationsUpdated(NEW_CONFIRMATIONS);

        rips.updateVrfRequestConfirmations(NEW_CONFIRMATIONS);

        assertEq(rips.vrfRequestConfirmations(), NEW_CONFIRMATIONS);
    }
}
