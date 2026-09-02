// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";

// The most expensive preset the protocol allows: the largest tier count, and an
// entryCap large enough that a buyer fills many whole chunks.
// Equal entries per tier, linearly increasing payouts:
// tier i averages (2i+1)/TIER_COUNT ether with a +/-30% spread,
// so the tiers together pay out exactly ENTRY_CAP ether.
contract Rips_MaxPreset is RipsTestBase {
    uint64 private constant ENTRY_CAP = 8192;
    uint256 private constant ENTRY_PRICE = 1 ether;
    uint256 private constant TIER_COUNT = 16;
    uint256 private constant ENTRIES_PER_TIER = ENTRY_CAP / TIER_COUNT;

    // a claim of one full chunk must stay well inside a block on Base
    uint256 private constant MAX_CLAIM_GAS_PER_CHUNK = 3_000_000;

    // leaves plenty of chunks behind, so the second claim can overshoot the remainder
    uint256 private constant FIRST_CLAIM_CHUNKS = 3;

    uint128 private constant MN_UNIT = 43_750_000_000_000_000;
    uint128 private constant MX_UNIT = 81_250_000_000_000_000;

    uint64 private presetId;
    uint256 private ripId;

    function setUp() public override {
        super.setUp();

        vrfCoordinator.fundSubscription(vrfSubscriptionId, 1000 ether);

        assertEq(TIER_COUNT, rips.MAX_TIER_COUNT());

        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](TIER_COUNT);

        for (uint256 i = 0; i < TIER_COUNT; i++) {
            uint128 k = uint128(2 * i + 1);

            tiers[i] = IRips.PayoutTier({
                payoutCount: uint64(ENTRIES_PER_TIER),
                minPayout: k * MN_UNIT,
                maxPayout: k * MX_UNIT
            });
        }

        vm.prank(owner);
        presetId = rips.createPreset(
            IRips.Config({
                currency: address(0),
                tiers: tiers,
                entryCap: ENTRY_CAP,
                duration: DEFAULT_DURATION,
                entryPrice: ENTRY_PRICE,
                feeBps: 0
            })
        );

        vm.deal(user, ENTRY_CAP * ENTRY_PRICE);
    }

    function _buyAllEntries() private {
        vm.prank(user);
        rips.enterRip{value: ENTRY_CAP * ENTRY_PRICE}(presetId, ENTRY_CAP, user);
        ripId = rips.presetIdToCurrentRipId(presetId);
    }

    function _finalizeRip() private {
        uint256 vrfRequestId = rips.requestRandomness(ripId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));
    }

    function test_ClaimPayout_MaxPreset() external {
        _buyAllEntries();
        _finalizeRip();

        uint256 balanceBefore = user.balance;

        IRips.EntryChunk[] memory chunks = rips.getUserEntries(ripId, user);

        for (uint256 i = 0; i < chunks.length; i++) {
            uint256 gasBefore = gasleft();

            vm.prank(user);
            rips.claimPayout(ripId, 1, user, referrer);

            assertLt(gasBefore - gasleft(), MAX_CLAIM_GAS_PER_CHUNK);
        }

        // the buyer owns every entry, so the whole pool is theirs and no fee is taken,
        // up to the per-entry rounding dust of the payout curve
        assertApproxEqAbs(user.balance - balanceBefore, ENTRY_CAP * ENTRY_PRICE, ENTRY_CAP);

        assertEq(rips.nextClaimChunkIndex(ripId, user), chunks.length);
    }

    function test_ClaimPayout_MaxChunksBeyondTheRemainingChunks() external {
        _buyAllEntries();
        _finalizeRip();

        uint256 balanceBefore = user.balance;

        IRips.EntryChunk[] memory chunks = rips.getUserEntries(ripId, user);

        vm.prank(user);
        rips.claimPayout(ripId, FIRST_CLAIM_CHUNKS, user, referrer);

        assertEq(rips.nextClaimChunkIndex(ripId, user), FIRST_CLAIM_CHUNKS);

        // asking for more than is left must stop at the end of the array, not overshoot
        vm.prank(user);
        rips.claimPayout(ripId, chunks.length * 2, user, referrer);

        assertEq(rips.nextClaimChunkIndex(ripId, user), chunks.length);

        // the two calls together still pay the whole pool exactly once
        assertApproxEqAbs(user.balance - balanceBefore, ENTRY_CAP * ENTRY_PRICE, ENTRY_CAP);

        vm.prank(user);
        vm.expectRevert(IRips.NothingToClaim.selector);
        rips.claimPayout(ripId, chunks.length, user, referrer);
    }

    function test_Refund_MaxPreset() external {
        uint64 entriesToBuy = ENTRY_CAP / 2;

        vm.prank(user);
        rips.enterRip{value: entriesToBuy * ENTRY_PRICE}(presetId, entriesToBuy, user);
        ripId = rips.presetIdToCurrentRipId(presetId);

        vm.warp(block.timestamp + DEFAULT_DURATION + 1);

        uint256 balanceBefore = user.balance;

        vm.prank(user);
        rips.refund(ripId, user);

        assertEq(user.balance, balanceBefore + entriesToBuy * ENTRY_PRICE);
    }
}
