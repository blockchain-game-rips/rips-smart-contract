// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract Rips_DeleteStake is RipsTestBase {
    uint256 private stakeId;

    uint256 private constant TICKET_CAP = 4;
    uint256 private constant TICKET_COST = 1 ether;

    function setUp() public override {
        super.setUp();

        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] =
            IRips.PrizeTier({prizeCount: TICKET_CAP, minPrize: TICKET_COST, maxPrize: TICKET_COST});

        vm.prank(owner);
        stakeId = rips.createStake(
            IRips.StakeConfig({
                prizeDistribution: tiers,
                ticketCap: TICKET_CAP,
                duration: 1 days,
                ticketCost: TICKET_COST
            })
        );
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
