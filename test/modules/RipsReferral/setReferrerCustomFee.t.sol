// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract Rips_SetReferrerCustomFee is RipsTestBase {
    event ReferrerCustomFeeUpdated(address indexed referrer, uint16 customFeeBps);

    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        vm.prank(user);
        vm.expectRevert();
        rips.setReferrerCustomFee(referrer, 500);
    }

    modifier whenTheCallerIsTheOwner() {
        vm.startPrank(owner);
        _;
        vm.stopPrank();
    }

    function test_RevertWhen_ReferrerIsZeroAddress() external whenTheCallerIsTheOwner {
        vm.expectRevert(IRips.ZeroAddress.selector);
        rips.setReferrerCustomFee(address(0), 500);
    }

    function test_RevertWhen_TheFeeIsGreaterThanFEE_BASE() external whenTheCallerIsTheOwner {
        vm.expectRevert(IRips.FeeTooHigh.selector);
        rips.setReferrerCustomFee(referrer, 10001);
    }

    function test_WhenInputsAreValid() external whenTheCallerIsTheOwner {
        uint16 customFee = 2000;

        vm.expectEmit();
        emit ReferrerCustomFeeUpdated(referrer, customFee);

        rips.setReferrerCustomFee(referrer, customFee);

        assertEq(rips.referrerCustomFee(referrer), customFee);
    }
}
