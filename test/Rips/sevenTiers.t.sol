// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";

// 7-tier preset, entryCap = 128, entryPrice = 1 ether
// Tiers ordered by highest payoutCount first to minimise linear search depth.
// Payout tiers (interpolated tiers, totalPool = 128 ether):
//   Tier 1: 50 payouts @ 0.1–0.5 ether   avg 0.3  = 15 ether
//   Tier 2: 34 payouts @ 0.3–0.7 ether   avg 0.5  = 17 ether
//   Tier 3: 20 payouts @ 0.5–1.5 ether   avg 1.0  = 20 ether
//   Tier 4: 12 payouts @ 1–3 ether       avg 2.0  = 24 ether
//   Tier 5:  8 payouts @ 2–4 ether       avg 3.0  = 24 ether
//   Tier 6:  3 payouts @ 4–8 ether       avg 6.0  = 18 ether
//   Tier 7:  1 payout  @ 10 ether        avg 10.0 = 10 ether
//                                            total = 128 ether
contract Rips_SevenTiers is RipsTestBase {
    uint64 private constant ENTRY_CAP = 128;
    uint256 private constant ENTRY_PRICE = 1 ether;

    uint64 private presetId;
    uint256 private ripId;

    function setUp() public override {
        super.setUp();

        vrfCoordinator.fundSubscription(vrfSubscriptionId, 1000 ether);

        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](7);
        tiers[0] = IRips.PayoutTier({payoutCount: 50, minPayout: 0.1 ether, maxPayout: 0.5 ether});
        tiers[1] = IRips.PayoutTier({payoutCount: 34, minPayout: 0.3 ether, maxPayout: 0.7 ether});
        tiers[2] = IRips.PayoutTier({payoutCount: 20, minPayout: 0.5 ether, maxPayout: 1.5 ether});
        tiers[3] = IRips.PayoutTier({payoutCount: 12, minPayout: 1 ether, maxPayout: 3 ether});
        tiers[4] = IRips.PayoutTier({payoutCount: 8, minPayout: 2 ether, maxPayout: 4 ether});
        tiers[5] = IRips.PayoutTier({payoutCount: 3, minPayout: 4 ether, maxPayout: 8 ether});
        tiers[6] = IRips.PayoutTier({payoutCount: 1, minPayout: 10 ether, maxPayout: 10 ether});

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

    function test_ClaimPayout_SevenTiers() external {
        _buyAllEntries();
        _finalizeRip();

        uint256 balanceBefore = user.balance;

        vm.prank(user);
        rips.claimPayout(ripId, 1, user, referrer);

        assertGt(user.balance, balanceBefore);

        assertEq(rips.nextClaimChunkIndex(ripId, user), 1);
    }

    function test_Refund_SevenTiers() external {
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
