// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";

contract Rips_GetUserEntries is RipsTestBase {
    uint64 private presetId;
    uint256 private ripId;

    function setUp() public override {
        super.setUp();

        presetId = _createDefaultPreset();
    }

    function test_WhenTheUserHasNoEntriesInTheRip() external {
        // rip doesn't exist yet — no entries bought — empty array expected
        uint256 nextRipId = rips.exposed_nextRipId();
        IRips.EntryChunk[] memory chunks = rips.getUserEntries(nextRipId, user);
        assertEq(chunks.length, 0);
    }

    function test_WhenTheUserHasEntriesInTheRip() external {
        uint64 entryCount = 2;

        vm.deal(user, entryCount * DEFAULT_ENTRY_PRICE);
        vm.prank(user);
        rips.enterRip{value: entryCount * DEFAULT_ENTRY_PRICE}(presetId, entryCount, user);

        ripId = rips.presetIdToCurrentRipId(presetId);
        IRips.EntryChunk[] memory chunks = rips.getUserEntries(ripId, user);
        assertEq(chunks.length, 1);
        assertEq(chunks[0].start, 0);
        assertEq(chunks[0].count, entryCount);
        assertFalse(chunks[0].claimed);
    }
}
