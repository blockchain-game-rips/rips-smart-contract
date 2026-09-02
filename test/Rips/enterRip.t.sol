// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";

contract Rips_EnterRip is RipsTestBase {
    // spills past one full chunk without filling a second
    uint64 private constant REMAINDER_ENTRIES = 24;

    uint64 private presetId;
    uint256 private ripId;
    uint64 private entriesToBuy;

    function setUp() public override {
        super.setUp();

        presetId = _createDefaultPreset();
        ripId = rips.exposed_nextRipId(); // rip is created lazily on first enterRip

        vm.deal(user, 100 ether);
    }

    function test_RevertWhen_TheContractIsPaused() external {
        vm.prank(owner);
        rips.pause();

        vm.prank(user);
        vm.expectRevert();
        rips.enterRip{value: DEFAULT_ENTRY_PRICE}(presetId, 1, user);
    }

    function test_RevertWhen_RecipientIsZeroAddress() external {
        vm.prank(user);
        vm.expectRevert();
        rips.enterRip{value: DEFAULT_ENTRY_PRICE}(presetId, 1, address(0));
    }

    function test_RevertWhen_ThePresetDoesNotExist() external {
        uint64 nonExistentPresetId = 999;

        vm.prank(user);
        vm.expectRevert(IRips.PresetNotExist.selector);
        rips.enterRip{value: DEFAULT_ENTRY_PRICE}(nonExistentPresetId, 1, user);
    }

    function test_RevertWhen_TheActiveRipHasExpiredAndThePresetIsDeleted() external {
        vm.prank(owner);
        rips.deletePreset(presetId);

        vm.warp(block.timestamp + DEFAULT_DURATION + 1);

        vm.prank(user);
        vm.expectRevert(IRips.PresetNotExist.selector);
        rips.enterRip{value: DEFAULT_ENTRY_PRICE}(presetId, 1, user);
    }

    function test_WhenTheActiveRipHasExpiredAndThePresetIsNotDeleted() external {
        // establish rip 1
        vm.prank(user);
        rips.enterRip{value: DEFAULT_ENTRY_PRICE}(presetId, 1, user);
        ripId = rips.presetIdToCurrentRipId(presetId);

        vm.warp(block.timestamp + DEFAULT_DURATION + 1);

        uint256 expectedNewRipId = rips.exposed_nextRipId();
        uint64 expectedConfigId = rips.presetIdToCurrentConfigId(presetId);

        vm.expectEmit();
        emit IRips.RipCreated(expectedNewRipId, presetId, expectedConfigId);

        vm.prank(user);
        rips.enterRip{value: DEFAULT_ENTRY_PRICE}(presetId, 1, user);

        uint256 newRipId = rips.presetIdToCurrentRipId(presetId);
        assertNotEq(newRipId, ripId);
    }

    function test_RevertWhen_EntryCountIsZero() external {
        vm.prank(user);
        vm.expectRevert(IRips.ZeroEntries.selector);
        rips.enterRip{value: 0}(presetId, 0, user);
    }

    modifier givenThePresetCurrencyIsNative() {
        _;
    }

    modifier whenRequestedEntriesAreFewerThanAvailable() {
        entriesToBuy = 2;
        _;
    }

    modifier whenRequestedEntriesEqualTheRemainingCapacity() {
        entriesToBuy = DEFAULT_ENTRY_CAP;
        _;
    }

    function test_RevertWhen_ThePaymentAmountIsIncorrect() external givenThePresetCurrencyIsNative {
        vm.prank(user);
        vm.expectRevert(IRips.IncorrectPayment.selector);
        rips.enterRip{value: DEFAULT_ENTRY_PRICE - 1}(presetId, 1, user);
    }

    function test_WhenRequestedEntriesAreFewerThanAvailable_GivenNative()
        external
        givenThePresetCurrencyIsNative
        whenRequestedEntriesAreFewerThanAvailable
    {
        vm.expectEmit();
        emit IRips.RipEntered(ripId, user, entriesToBuy, 0);

        vm.prank(user);
        rips.enterRip{value: entriesToBuy * DEFAULT_ENTRY_PRICE}(presetId, entriesToBuy, user);

        IRips.Rip memory rip = rips.exposed_rip(ripId);
        assertEq(rip.entriesSold, entriesToBuy);

        IRips.EntryChunk[] memory chunks = rips.getUserEntries(ripId, user);
        assertEq(chunks.length, 1);
        assertEq(chunks[0].start, 0);
        assertEq(chunks[0].count, entriesToBuy);
    }

    function test_WhenRecipientIsDifferentFromTheCaller()
        external
        givenThePresetCurrencyIsNative
        whenRequestedEntriesAreFewerThanAvailable
    {
        address recipient = makeAddr("recipient");

        vm.prank(user);
        rips.enterRip{value: entriesToBuy * DEFAULT_ENTRY_PRICE}(presetId, entriesToBuy, recipient);

        IRips.EntryChunk[] memory recipientChunks = rips.getUserEntries(ripId, recipient);
        assertEq(recipientChunks.length, 1);
        assertEq(recipientChunks[0].count, entriesToBuy);

        IRips.EntryChunk[] memory callerChunks = rips.getUserEntries(ripId, user);
        assertEq(callerChunks.length, 0);
    }

    function test_WhenEntryCountExceedsMAX_ENTRIES_PER_CHUNK()
        external
        givenThePresetCurrencyIsNative
        whenRequestedEntriesAreFewerThanAvailable
    {
        uint64 largeEntryCap = 2048;
        uint256 entryPrice = 0.01 ether;

        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](1);
        tiers[0] = IRips.PayoutTier({
            payoutCount: largeEntryCap, minPayout: uint128(entryPrice), maxPayout: uint128(entryPrice)
        });

        vm.prank(owner);
        uint64 largePresetId = rips.createPreset(
            IRips.Config({
                currency: address(0),
                tiers: tiers,
                entryCap: largeEntryCap,
                duration: DEFAULT_DURATION,
                entryPrice: entryPrice,
                feeBps: 0
            })
        );

        entriesToBuy = uint64(rips.MAX_ENTRIES_PER_CHUNK()) + REMAINDER_ENTRIES;

        vm.prank(user);
        rips.enterRip{value: entriesToBuy * entryPrice}(largePresetId, entriesToBuy, user);

        uint256 largeRipId = rips.presetIdToCurrentRipId(largePresetId);
        IRips.EntryChunk[] memory chunks = rips.getUserEntries(largeRipId, user);
        assertEq(chunks.length, 2);
        assertEq(chunks[0].count, rips.MAX_ENTRIES_PER_CHUNK());
        assertEq(chunks[1].count, REMAINDER_ENTRIES);
    }

    function test_WhenRequestedEntriesEqualTheRemainingCapacity()
        external
        givenThePresetCurrencyIsNative
        whenRequestedEntriesEqualTheRemainingCapacity
    {
        vm.expectEmit();
        emit IRips.RipEntered(ripId, user, entriesToBuy, 0);

        vm.prank(user);
        rips.enterRip{value: entriesToBuy * DEFAULT_ENTRY_PRICE}(presetId, entriesToBuy, user);

        IRips.Rip memory rip = rips.exposed_rip(ripId);
        assertEq(rip.entriesSold, DEFAULT_ENTRY_CAP);
        assertEq(uint256(rip.vrfRequestStatus), uint256(IRips.VrfRequestStatus.NotRequested));
    }

    function test_GivenThePresetIsNotDeleted()
        external
        givenThePresetCurrencyIsNative
        whenRequestedEntriesEqualTheRemainingCapacity
    {
        // fill rip 1 completely
        vm.prank(user);
        rips.enterRip{value: entriesToBuy * DEFAULT_ENTRY_PRICE}(presetId, entriesToBuy, user);
        ripId = rips.presetIdToCurrentRipId(presetId);

        // buying again triggers creation of rip 2
        uint256 expectedNewRipId = rips.exposed_nextRipId();

        vm.prank(user);
        rips.enterRip{value: DEFAULT_ENTRY_PRICE}(presetId, 1, user);

        uint256 newActiveRip = rips.presetIdToCurrentRipId(presetId);
        assertEq(newActiveRip, expectedNewRipId);
        assertNotEq(newActiveRip, ripId);
    }

    function test_GivenThePresetIsDeleted()
        external
        givenThePresetCurrencyIsNative
        whenRequestedEntriesEqualTheRemainingCapacity
    {
        // fill rip 1 completely
        vm.prank(user);
        rips.enterRip{value: entriesToBuy * DEFAULT_ENTRY_PRICE}(presetId, entriesToBuy, user);
        ripId = rips.presetIdToCurrentRipId(presetId);

        vm.prank(owner);
        rips.deletePreset(presetId);

        // buying again on a sold-out deleted preset should revert — no new rip created
        vm.prank(user);
        vm.expectRevert(IRips.PresetNotExist.selector);
        rips.enterRip{value: DEFAULT_ENTRY_PRICE}(presetId, 1, user);

        // mapping still points to the sold-out rip, not a new one
        assertEq(rips.presetIdToCurrentRipId(presetId), ripId);
    }

    function test_WhenRequestedEntriesExceedAvailableEntries() external givenThePresetCurrencyIsNative {
        uint64 initialBuy = DEFAULT_ENTRY_CAP - 1;
        vm.prank(user);
        rips.enterRip{value: initialBuy * DEFAULT_ENTRY_PRICE}(presetId, initialBuy, user);

        entriesToBuy = 3;
        uint64 availableEntries = DEFAULT_ENTRY_CAP - initialBuy;
        uint256 payment = entriesToBuy * DEFAULT_ENTRY_PRICE;
        uint256 expectedRefund = (entriesToBuy - availableEntries) * DEFAULT_ENTRY_PRICE;

        uint256 balanceBefore = user.balance;

        vm.expectEmit();
        emit IRips.RipEntered(ripId, user, availableEntries, initialBuy);

        vm.prank(user);
        rips.enterRip{value: payment}(presetId, entriesToBuy, user);

        IRips.Rip memory rip = rips.exposed_rip(ripId);
        assertEq(rip.entriesSold, DEFAULT_ENTRY_CAP);
        assertEq(uint256(rip.vrfRequestStatus), uint256(IRips.VrfRequestStatus.NotRequested));

        assertEq(user.balance, balanceBefore - payment + expectedRefund);
    }

    function test_WhenRecipientIsDifferentFromTheCaller_WhenRequestedEntriesExceedAvailableEntries()
        external
        givenThePresetCurrencyIsNative
    {
        uint64 initialBuy = DEFAULT_ENTRY_CAP - 1;
        vm.prank(user);
        rips.enterRip{value: initialBuy * DEFAULT_ENTRY_PRICE}(presetId, initialBuy, user);

        address recipient = makeAddr("recipient");

        entriesToBuy = 3;
        uint64 availableEntries = DEFAULT_ENTRY_CAP - initialBuy;
        uint256 payment = entriesToBuy * DEFAULT_ENTRY_PRICE;
        uint256 expectedSpent = availableEntries * DEFAULT_ENTRY_PRICE;

        uint256 balanceBefore = user.balance;

        vm.prank(user);
        rips.enterRip{value: payment}(presetId, entriesToBuy, recipient);

        IRips.Rip memory rip = rips.exposed_rip(ripId);
        assertEq(rip.entriesSold, DEFAULT_ENTRY_CAP);

        IRips.EntryChunk[] memory recipientChunks = rips.getUserEntries(ripId, recipient);
        assertEq(recipientChunks.length, 1);
        assertEq(recipientChunks[0].count, availableEntries);

        assertEq(user.balance, balanceBefore - expectedSpent);
        assertEq(recipient.balance, 0);
    }

    modifier givenThePresetCurrencyIsAnERC20Token() {
        presetId = _createDefaultERC20Preset();
        _mintAndApprove(user, 100 ether);
        // ripId is set after first enterRip since rip is created lazily
        ripId = rips.exposed_nextRipId();
        _;
    }

    function test_RevertWhen_ETHIsSent() external givenThePresetCurrencyIsAnERC20Token {
        vm.prank(user);
        vm.expectRevert(IRips.EthSentForERC20.selector);
        rips.enterRip{value: 1}(presetId, 1, user);
    }

    function test_WhenRequestedEntriesAreFewerThanAvailable()
        external
        givenThePresetCurrencyIsAnERC20Token
        whenRequestedEntriesAreFewerThanAvailable
    {
        uint256 expectedCost = entriesToBuy * DEFAULT_ENTRY_PRICE;
        uint256 balanceBefore = erc20.balanceOf(user);

        vm.expectEmit();
        emit IRips.RipEntered(ripId, user, entriesToBuy, 0);

        vm.prank(user);
        rips.enterRip(presetId, entriesToBuy, user);

        assertEq(erc20.balanceOf(user), balanceBefore - expectedCost);

        IRips.Rip memory rip = rips.exposed_rip(ripId);
        assertEq(rip.entriesSold, entriesToBuy);

        IRips.EntryChunk[] memory chunks = rips.getUserEntries(ripId, user);
        assertEq(chunks.length, 1);
        assertEq(chunks[0].count, entriesToBuy);
    }

    function test_WhenRecipientIsDifferentFromTheCaller_GivenERC20()
        external
        givenThePresetCurrencyIsAnERC20Token
        whenRequestedEntriesAreFewerThanAvailable
    {
        address recipient = makeAddr("recipient");

        vm.prank(user);
        rips.enterRip(presetId, entriesToBuy, recipient);

        IRips.EntryChunk[] memory recipientChunks = rips.getUserEntries(ripId, recipient);
        assertEq(recipientChunks.length, 1);
        assertEq(recipientChunks[0].count, entriesToBuy);

        IRips.EntryChunk[] memory callerChunks = rips.getUserEntries(ripId, user);
        assertEq(callerChunks.length, 0);
    }

    function test_WhenEntryCountExceedsMAX_ENTRIES_PER_CHUNK_GivenERC20()
        external
        givenThePresetCurrencyIsAnERC20Token
        whenRequestedEntriesAreFewerThanAvailable
    {
        uint64 largeEntryCap = 2048;
        uint256 entryPrice = 0.01 ether;

        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](1);
        tiers[0] = IRips.PayoutTier({
            payoutCount: largeEntryCap, minPayout: uint128(entryPrice), maxPayout: uint128(entryPrice)
        });

        vm.prank(owner);
        uint64 largePresetId = rips.createPreset(
            IRips.Config({
                currency: address(erc20),
                tiers: tiers,
                entryCap: largeEntryCap,
                duration: DEFAULT_DURATION,
                entryPrice: entryPrice,
                feeBps: 0
            })
        );

        entriesToBuy = uint64(rips.MAX_ENTRIES_PER_CHUNK()) + REMAINDER_ENTRIES;

        vm.prank(user);
        rips.enterRip(largePresetId, entriesToBuy, user);

        uint256 largeRipId = rips.presetIdToCurrentRipId(largePresetId);
        IRips.EntryChunk[] memory chunks = rips.getUserEntries(largeRipId, user);
        assertEq(chunks.length, 2);
        assertEq(chunks[0].count, rips.MAX_ENTRIES_PER_CHUNK());
        assertEq(chunks[1].count, REMAINDER_ENTRIES);
    }

    function test_WhenRequestedEntriesEqualTheRemainingCapacity_GivenERC20()
        external
        givenThePresetCurrencyIsAnERC20Token
        whenRequestedEntriesEqualTheRemainingCapacity
    {
        uint256 expectedCost = DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE;
        uint256 balanceBefore = erc20.balanceOf(user);

        vm.expectEmit();
        emit IRips.RipEntered(ripId, user, entriesToBuy, 0);

        vm.prank(user);
        rips.enterRip(presetId, entriesToBuy, user);

        assertEq(erc20.balanceOf(user), balanceBefore - expectedCost);

        IRips.Rip memory rip = rips.exposed_rip(ripId);
        assertEq(rip.entriesSold, DEFAULT_ENTRY_CAP);
        assertEq(uint256(rip.vrfRequestStatus), uint256(IRips.VrfRequestStatus.NotRequested));
    }

    function test_WhenRequestedEntriesExceedAvailableEntries_GivenERC20()
        external
        givenThePresetCurrencyIsAnERC20Token
    {
        uint64 initialBuy = DEFAULT_ENTRY_CAP - 1;
        vm.prank(user);
        rips.enterRip(presetId, initialBuy, user);

        entriesToBuy = 3;
        uint64 availableEntries = DEFAULT_ENTRY_CAP - initialBuy;
        uint256 expectedCost = availableEntries * DEFAULT_ENTRY_PRICE;
        uint256 balanceBefore = erc20.balanceOf(user);

        vm.expectEmit();
        emit IRips.RipEntered(ripId, user, availableEntries, initialBuy);

        vm.prank(user);
        rips.enterRip(presetId, entriesToBuy, user);

        assertEq(erc20.balanceOf(user), balanceBefore - expectedCost);

        IRips.Rip memory rip = rips.exposed_rip(ripId);
        assertEq(rip.entriesSold, DEFAULT_ENTRY_CAP);
        assertEq(uint256(rip.vrfRequestStatus), uint256(IRips.VrfRequestStatus.NotRequested));
    }
}
