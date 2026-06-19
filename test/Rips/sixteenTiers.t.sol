// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";

// 16-tier preset, entryCap = 1024, entryPrice = 1 ether
// Equal 64 entries per tier, linearly increasing payouts.
// avg_i = (2i+1)/16 ether, spread ±30%, totalPool = 1024 ether
contract Rips_SixteenTiers is RipsTestBase {
    uint64 private constant ENTRY_CAP = 1024;
    uint256 private constant ENTRY_PRICE = 1 ether;
    uint256 private constant TIER_COUNT = 16;
    uint256 private constant ENTRIES_PER_TIER = ENTRY_CAP / TIER_COUNT;

    uint128 private constant MN_UNIT = 43_750_000_000_000_000;
    uint128 private constant MX_UNIT = 81_250_000_000_000_000;

    uint64 private presetId;
    uint256 private ripId;

    function setUp() public override {
        super.setUp();

        vrfCoordinator.fundSubscription(vrfSubscriptionId, 1000 ether);

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
                feePercent: 0
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

    function test_ClaimPayout_SixteenTiers() external {
        _buyAllEntries();
        _finalizeRip();

        uint256 balanceBefore = user.balance;

        vm.prank(user);
        rips.claimPayout(ripId, 0, 2, user, referrer);

        assertGt(user.balance, balanceBefore);

        IRips.EntryRange[] memory ranges = rips.getUserEntries(ripId, user);
        assertTrue(ranges[0].claimed);
        assertTrue(ranges[1].claimed);
    }

    function test_Refund_SixteenTiers() external {
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
