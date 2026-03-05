// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

contract Rips_SetFeeRecipient is RipsTestBase {
    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        vm.prank(user);
        vm.expectRevert();
        rips.setFeeRecipient(user);
    }

    modifier whenTheCallerIsTheOwner() {
        vm.startPrank(owner);
        _;
        vm.stopPrank();
    }

    function test_RevertWhen_TheNewRecipientIsTheZeroAddress() external whenTheCallerIsTheOwner {
        vm.expectRevert(VRFConsumerBaseV2Plus.ZeroAddress.selector);
        rips.setFeeRecipient(address(0));
    }

    function test_WhenTheNewRecipientIsNotTheZeroAddress() external whenTheCallerIsTheOwner {
        address newRecipient = makeAddr("newRecipient");

        vm.expectEmit();
        emit IRips.FeeRecipientUpdated(newRecipient);
        rips.setFeeRecipient(newRecipient);

        assertEq(rips.feeRecipient(), newRecipient);
    }
}
