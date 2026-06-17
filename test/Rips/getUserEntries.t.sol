// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";

contract Rips_GetUserEntries is RipsTestBase {
    uint64 private stakeId;
    uint256 private ripId;

    function setUp() public override {
        super.setUp();

        stakeId = _createDefaultStake();
    }

    function test_WhenTheUserHasNoEntriesInTheRip() external {
        // rip doesn't exist yet — no entries bought — empty array expected
        uint256 nextRipId = rips.exposed_nextRipId();
        IRips.EntryRange[] memory ranges = rips.getUserEntries(nextRipId, user);
        assertEq(ranges.length, 0);
    }

    function test_WhenTheUserHasEntriesInTheRip() external {
        uint64 entryCount = 2;

        vm.deal(user, entryCount * DEFAULT_ENTRY_PRICE);
        vm.prank(user);
        rips.enterRip{value: entryCount * DEFAULT_ENTRY_PRICE}(stakeId, entryCount, user);

        ripId = rips.stakeIdToCurrentRipId(stakeId);
        IRips.EntryRange[] memory ranges = rips.getUserEntries(ripId, user);
        assertEq(ranges.length, 1);
        assertEq(ranges[0].start, 0);
        assertEq(ranges[0].count, entryCount);
        assertFalse(ranges[0].claimed);
    }
}
