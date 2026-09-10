// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract Rips_CancelRip is RipsTestBase {
    uint64 private constant ENTRIES_BOUGHT = 2;

    uint64 private presetId;
    uint256 private ripId;

    function setUp() public override {
        super.setUp();

        presetId = _createDefaultPreset();

        vm.deal(user, 100 ether);
        vm.prank(user);
        rips.enterRip{value: ENTRIES_BOUGHT * DEFAULT_ENTRY_PRICE}(presetId, ENTRIES_BOUGHT, user);

        ripId = rips.presetIdToCurrentRipId(presetId);
    }

    function _sellOut() private {
        uint64 remaining = DEFAULT_ENTRY_CAP - ENTRIES_BOUGHT;

        vm.prank(user);
        rips.enterRip{value: remaining * DEFAULT_ENTRY_PRICE}(presetId, remaining, user);
    }

    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        vm.prank(user);
        vm.expectRevert();
        rips.cancelRip(ripId);
    }

    modifier whenTheCallerIsTheOwner() {
        vm.startPrank(owner);
        _;
        vm.stopPrank();
    }

    function test_RevertWhen_TheRipDoesNotExist() external whenTheCallerIsTheOwner {
        uint256 nonExistentRipId = 999;

        vm.expectRevert(IRips.RipNotExist.selector);
        rips.cancelRip(nonExistentRipId);
    }

    function test_RevertWhen_TheRipIsSoldOut() external {
        _sellOut();

        vm.prank(owner);
        vm.expectRevert(IRips.RipNotCancellable.selector);
        rips.cancelRip(ripId);
    }

    function test_RevertWhen_TheRipIsAwaitingRandomness() external {
        _sellOut();
        rips.requestRandomness(ripId);

        vm.prank(owner);
        vm.expectRevert(IRips.RipNotCancellable.selector);
        rips.cancelRip(ripId);
    }

    function test_RevertWhen_TheRipIsAlreadyCancelled() external whenTheCallerIsTheOwner {
        rips.cancelRip(ripId);

        vm.expectRevert(IRips.RipNotCancellable.selector);
        rips.cancelRip(ripId);
    }

    function test_WhenTheRipIsFilling_ItMarksTheRipAsCancelled() external whenTheCallerIsTheOwner {
        rips.cancelRip(ripId);

        assertTrue(rips.exposed_rip(ripId).isCancelled);
    }

    function test_WhenTheRipIsFilling_ItEmitsARipCancelledEvent() external whenTheCallerIsTheOwner {
        vm.expectEmit();
        emit IRips.RipCancelled(ripId);
        rips.cancelRip(ripId);
    }

    function test_WhenTheRipIsFilling_ItLetsAnEntrantRefund() external {
        vm.prank(owner);
        rips.cancelRip(ripId);

        uint256 balanceBefore = user.balance;

        vm.prank(user);
        rips.refund(ripId, user);

        assertEq(user.balance - balanceBefore, ENTRIES_BOUGHT * DEFAULT_ENTRY_PRICE);
    }

    function test_WhenTheRipIsFilling_ItRejectsFurtherEntriesIntoTheCancelledRip() external {
        vm.prank(owner);
        rips.cancelRip(ripId);

        vm.prank(user);
        rips.enterRip{value: DEFAULT_ENTRY_PRICE}(presetId, 1, user);

        assertNotEq(rips.presetIdToCurrentRipId(presetId), ripId);
        assertEq(rips.exposed_rip(ripId).entriesSold, ENTRIES_BOUGHT);
    }

    function test_WhenTheRipIsFilling_ItCreatesAFreshRipOnTheCurrentConfigForTheNextEntry() external {
        uint32 correctedDuration = 2 days;

        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](1);
        tiers[0] = IRips.PayoutTier({
            payoutCount: uint64(DEFAULT_ENTRY_CAP),
            minPayout: uint128(DEFAULT_ENTRY_PRICE),
            maxPayout: uint128(DEFAULT_ENTRY_PRICE)
        });

        vm.startPrank(owner);
        rips.updatePreset(
            presetId,
            IRips.Config({
                currency: address(0),
                tiers: tiers,
                entryCap: DEFAULT_ENTRY_CAP,
                duration: correctedDuration,
                entryPrice: DEFAULT_ENTRY_PRICE,
                feeBps: DEFAULT_FEE_PERCENT
            })
        );
        rips.cancelRip(ripId);
        vm.stopPrank();

        vm.prank(user);
        rips.enterRip{value: DEFAULT_ENTRY_PRICE}(presetId, 1, user);

        uint256 freshRipId = rips.presetIdToCurrentRipId(presetId);
        uint64 freshConfigId = rips.exposed_rip(freshRipId).configId;

        assertNotEq(freshRipId, ripId);
        assertEq(rips.exposed_config(freshConfigId).duration, correctedDuration);
    }

    function test_WhenTheProtocolIsPaused_ItStillCancels() external whenTheCallerIsTheOwner {
        rips.pause();

        rips.cancelRip(ripId);

        assertTrue(rips.exposed_rip(ripId).isCancelled);
    }
}
