// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";

contract Rips_Constructor is RipsTestBase {
    function test_RevertWhen_InitialOwnerIsZeroAddress() external {
        vm.expectRevert();
        new RipsHarness(
            address(vrfCoordinator),
            vrfSubscriptionId,
            VRF_KEY_HASH,
            VRF_CALLBACK_GAS_LIMIT,
            address(0),
            INITIAL_FEE_PERCENT
        );
    }

    function test_WhenInitialOwnerIsNotZeroAddress() external view {
        assertEq(rips.owner(), owner);
        assertEq(rips.feeRecipient(), owner);
        assertEq(rips.protocolFeePercent(), INITIAL_FEE_PERCENT);
    }
}
