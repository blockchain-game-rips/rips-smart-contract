// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract Rips_SetReferrerCustomFee is RipsTestBase {
    event ReferrerCustomFeeSet(address indexed referrer, uint16 customFeePercent);

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

    function test_RevertWhen_TheFeeIsGreaterThan10000() external whenTheCallerIsTheOwner {
        vm.expectRevert(IRips.FeeTooHigh.selector);
        rips.setReferrerCustomFee(referrer, 10001);
    }

    function test_WhenInputsAreValid() external whenTheCallerIsTheOwner {
        uint16 customFee = 2000;

        vm.expectEmit();
        emit ReferrerCustomFeeSet(referrer, customFee);

        rips.setReferrerCustomFee(referrer, customFee);

        IRips.ReferrerStats memory stats = rips.exposed_referrerStats(referrer);
        assertEq(stats.customFeePercent, customFee);
    }
}
