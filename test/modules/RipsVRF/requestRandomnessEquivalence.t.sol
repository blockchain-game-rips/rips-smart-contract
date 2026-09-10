// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

// requestRandomness gates on the lifecycle ladder rather than on _isSoldOut directly.
// Past the VrfAlreadyRequested check a rip is always NotRequested, and this pins what
// that reduces to: the ladder accepts exactly the sold-out rips, whatever the clock is
// doing. It does not exercise the ladder's Requested or Fulfilled branches, which
// requestRandomness can never reach.
contract Rips_RequestRandomnessEquivalence is RipsTestBase {
    uint64 private constant ENTRY_CAP = 2;
    uint256 private constant ENTRY_PRICE = 1 ether;

    function _preset() private returns (uint64 presetId) {
        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](1);
        tiers[0] = IRips.PayoutTier({
            payoutCount: uint64(ENTRY_CAP), minPayout: uint128(ENTRY_PRICE), maxPayout: uint128(ENTRY_PRICE)
        });

        vm.prank(owner);
        presetId = rips.createPreset(
            IRips.Config({
                currency: address(0),
                tiers: tiers,
                entryCap: ENTRY_CAP,
                duration: 1 days,
                entryPrice: ENTRY_PRICE,
                feeBps: 0
            })
        );
    }

    function testFuzz_NotRequestedRipAcceptsRequestIffSoldOut(uint8 entries, uint32 elapsed) external {
        uint64 bought = uint64(bound(entries, 1, ENTRY_CAP));
        uint64 presetId = _preset();

        vm.deal(user, bought * ENTRY_PRICE);
        vm.prank(user);
        rips.enterRip{value: bought * ENTRY_PRICE}(presetId, bought, user);

        uint256 ripId = rips.presetIdToCurrentRipId(presetId);

        vm.warp(block.timestamp + elapsed);
        vrfCoordinator.fundSubscription(vrfSubscriptionId, 100 ether);

        bool soldOut = bought == ENTRY_CAP;

        if (!soldOut) vm.expectRevert(IRips.RipNotSoldOut.selector);

        rips.requestRandomness(ripId);
    }
}
