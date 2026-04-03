// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract Rips_SetBaseFeePercent is RipsTestBase {
    event BaseFeePercentUpdated(uint16 newBaseFeePercent);

    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        vm.prank(user);
        vm.expectRevert();
        rips.setBaseFeePercent(100);
    }

    modifier whenTheCallerIsTheOwner() {
        vm.startPrank(owner);
        _;
        vm.stopPrank();
    }

    function test_RevertWhen_TheFeeIsGreaterThan10000() external whenTheCallerIsTheOwner {
        vm.expectRevert(IRips.FeeTooHigh.selector);
        rips.setBaseFeePercent(10001);
    }

    function test_WhenTheFeeIsValid() external whenTheCallerIsTheOwner {
        uint16 newFee = 500;

        vm.expectEmit();
        emit BaseFeePercentUpdated(newFee);

        rips.setBaseFeePercent(newFee);

        assertEq(rips.baseFeePercent(), newFee);
    }
}
