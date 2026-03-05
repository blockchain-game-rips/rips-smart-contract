// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract Rips_SetProtocolFee is RipsTestBase {
    uint256 private constant MAX_FEE_PERCENT = 10000;

    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        vm.prank(user);
        vm.expectRevert();
        rips.setProtocolFee(500);
    }

    modifier whenTheCallerIsTheOwner() {
        vm.startPrank(owner);
        _;
        vm.stopPrank();
    }

    function test_RevertWhen_TheNewFeeExceeds10000() external whenTheCallerIsTheOwner {
        vm.expectRevert(IRips.FeeTooHigh.selector);
        rips.setProtocolFee(MAX_FEE_PERCENT + 1);
    }

    function test_WhenTheNewFeeIsAtMost10000() external whenTheCallerIsTheOwner {
        uint256 newFee = 300;

        vm.expectEmit();
        emit IRips.ProtocolFeeUpdated(newFee);
        rips.setProtocolFee(newFee);

        assertEq(rips.protocolFeePercent(), newFee);
    }
}
