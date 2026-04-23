// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract Rips_SetReferrerCustomFee is RipsTestBase {
    event ReferralStatsUpdated(IRips.ReferrerState referralStats);

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

        IRips.ReferrerState memory expectedStats = IRips.ReferrerState({
            activeFeePercent: 0,
            customFeePercent: customFee,
            monthStartTimestamp: 0,
            currMonthVolume: 0
        });

        vm.expectEmit();
        emit ReferralStatsUpdated(expectedStats);

        rips.setReferrerCustomFee(referrer, customFee);

        IRips.ReferrerState memory stats = rips.exposed_referrerStats(referrer);
        assertEq(stats.customFeePercent, customFee);
    }
}
