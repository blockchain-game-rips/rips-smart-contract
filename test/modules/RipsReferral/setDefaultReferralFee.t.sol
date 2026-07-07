// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract Rips_SetDefaultReferralFee is RipsTestBase {
    event DefaultReferralFeeUpdated(uint16 newDefaultReferralFeeBps);

    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        vm.prank(user);
        vm.expectRevert();
        rips.setDefaultReferralFee(100);
    }

    modifier whenTheCallerIsTheOwner() {
        vm.startPrank(owner);
        _;
        vm.stopPrank();
    }

    function test_RevertWhen_TheFeeIsGreaterThanFEE_BASE() external whenTheCallerIsTheOwner {
        vm.expectRevert(IRips.FeeTooHigh.selector);
        rips.setDefaultReferralFee(10001);
    }

    function test_WhenTheFeeIsValid() external whenTheCallerIsTheOwner {
        uint16 newFee = 500;

        vm.expectEmit();
        emit DefaultReferralFeeUpdated(newFee);

        rips.setDefaultReferralFee(newFee);

        assertEq(rips.defaultReferralFeeBps(), newFee);
    }
}
