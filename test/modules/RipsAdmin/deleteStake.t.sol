// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract Rips_DeleteStake is RipsTestBase {
    uint256 private stakeId;

    function setUp() public override {
        super.setUp();

        stakeId = _createDefaultStake();
    }

    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        vm.prank(user);
        vm.expectRevert();
        rips.deleteStake(stakeId);
    }

    modifier whenTheCallerIsTheOwner() {
        vm.startPrank(owner);
        _;
        vm.stopPrank();
    }

    function test_RevertWhen_TheStakeIsAlreadyDeleted() external whenTheCallerIsTheOwner {
        rips.deleteStake(stakeId);

        vm.expectRevert(IRips.StakeNotExist.selector);
        rips.deleteStake(stakeId);
    }

    function test_WhenTheStakeIsNotDeleted() external whenTheCallerIsTheOwner {
        vm.expectEmit();
        emit IRips.StakeDeleted(stakeId);
        rips.deleteStake(stakeId);
    }
}
