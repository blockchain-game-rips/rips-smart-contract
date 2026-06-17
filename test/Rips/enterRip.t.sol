// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";

contract Rips_EnterRip is RipsTestBase {
    uint64 private stakeId;
    uint256 private ripId;
    uint64 private entriesToBuy;

    function setUp() public override {
        super.setUp();

        stakeId = _createDefaultStake();
        ripId = rips.exposed_nextRipId(); // rip is created lazily on first enterRip

        vm.deal(user, 100 ether);
    }

    function test_RevertWhen_TheContractIsPaused() external {
        vm.prank(owner);
        rips.pause();

        vm.prank(user);
        vm.expectRevert();
        rips.enterRip{value: DEFAULT_ENTRY_PRICE}(stakeId, 1, user);
    }

    function test_RevertWhen_RecipientIsZeroAddress() external {
        vm.prank(user);
        vm.expectRevert();
        rips.enterRip{value: DEFAULT_ENTRY_PRICE}(stakeId, 1, address(0));
    }

    function test_RevertWhen_TheStakeDoesNotExist() external {
        uint64 nonExistentStakeId = 999;

        vm.prank(user);
        vm.expectRevert(IRips.StakeNotExist.selector);
        rips.enterRip{value: DEFAULT_ENTRY_PRICE}(nonExistentStakeId, 1, user);
    }

    function test_RevertWhen_TheActiveRipHasExpiredAndTheStakeIsDeleted() external {
        vm.prank(owner);
        rips.deleteStake(stakeId);

        vm.warp(block.timestamp + DEFAULT_DURATION + 1);

        vm.prank(user);
        vm.expectRevert(IRips.StakeNotExist.selector);
        rips.enterRip{value: DEFAULT_ENTRY_PRICE}(stakeId, 1, user);
    }

    function test_WhenTheActiveRipHasExpiredAndTheStakeIsNotDeleted() external {
        // establish rip 1
        vm.prank(user);
        rips.enterRip{value: DEFAULT_ENTRY_PRICE}(stakeId, 1, user);
        ripId = rips.stakeIdToCurrentRipId(stakeId);

        vm.warp(block.timestamp + DEFAULT_DURATION + 1);

        uint256 expectedNewRipId = rips.exposed_nextRipId();
        uint64 expectedConfigId = rips.stakeIdToCurrentConfigId(stakeId);

        vm.expectEmit();
        emit IRips.RipCreated(expectedNewRipId, stakeId, expectedConfigId);

        vm.prank(user);
        rips.enterRip{value: DEFAULT_ENTRY_PRICE}(stakeId, 1, user);

        uint256 newRipId = rips.stakeIdToCurrentRipId(stakeId);
        assertNotEq(newRipId, ripId);
    }

    function test_RevertWhen_EntryCountIsZero() external {
        vm.prank(user);
        vm.expectRevert(IRips.ZeroEntries.selector);
        rips.enterRip{value: 0}(stakeId, 0, user);
    }

    modifier givenTheStakeCurrencyIsNative() {
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

    function test_RevertWhen_ThePaymentAmountIsIncorrect() external givenTheStakeCurrencyIsNative {
        vm.prank(user);
        vm.expectRevert(IRips.IncorrectPayment.selector);
        rips.enterRip{value: DEFAULT_ENTRY_PRICE - 1}(stakeId, 1, user);
    }

    function test_WhenRequestedEntriesAreFewerThanAvailable_GivenNative()
        external
        givenTheStakeCurrencyIsNative
        whenRequestedEntriesAreFewerThanAvailable
    {
        vm.expectEmit();
        emit IRips.RipEntered(ripId, user, entriesToBuy, 0);

        vm.prank(user);
        rips.enterRip{value: entriesToBuy * DEFAULT_ENTRY_PRICE}(stakeId, entriesToBuy, user);

        IRips.Rip memory rip = rips.exposed_rip(ripId);
        assertEq(rip.entriesSold, entriesToBuy);

        IRips.EntryRange[] memory ranges = rips.getUserEntries(ripId, user);
        assertEq(ranges.length, 1);
        assertEq(ranges[0].start, 0);
        assertEq(ranges[0].count, entriesToBuy);
    }

    function test_WhenRecipientIsDifferentFromTheCaller()
        external
        givenTheStakeCurrencyIsNative
        whenRequestedEntriesAreFewerThanAvailable
    {
        address recipient = makeAddr("recipient");

        vm.prank(user);
        rips.enterRip{value: entriesToBuy * DEFAULT_ENTRY_PRICE}(stakeId, entriesToBuy, recipient);

        IRips.EntryRange[] memory recipientRanges = rips.getUserEntries(ripId, recipient);
        assertEq(recipientRanges.length, 1);
        assertEq(recipientRanges[0].count, entriesToBuy);

        IRips.EntryRange[] memory callerRanges = rips.getUserEntries(ripId, user);
        assertEq(callerRanges.length, 0);
    }

    function test_WhenEntryCountExceedsMAX_ENTRIES_PER_RANGE()
        external
        givenTheStakeCurrencyIsNative
        whenRequestedEntriesAreFewerThanAvailable
    {
        uint64 largeEntryCap = 2048;
        uint256 entryPrice = 0.01 ether;

        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](1);
        tiers[0] = IRips.PayoutTier({
            payoutCount: largeEntryCap,
            minPayout: uint128(entryPrice),
            maxPayout: uint128(entryPrice)
        });

        vm.prank(owner);
        uint64 largeStakeId = rips.createStake(
            IRips.Config({
                currency: address(0),
                tiers: tiers,
                entryCap: largeEntryCap,
                duration: DEFAULT_DURATION,
                entryPrice: entryPrice,
                feePercent: 0
            })
        );

        entriesToBuy = 1500;

        vm.prank(user);
        rips.enterRip{value: entriesToBuy * entryPrice}(largeStakeId, entriesToBuy, user);

        uint256 largeRipId = rips.stakeIdToCurrentRipId(largeStakeId);
        IRips.EntryRange[] memory ranges = rips.getUserEntries(largeRipId, user);
        assertEq(ranges.length, 2);
        assertEq(ranges[0].count, 1000);
        assertEq(ranges[1].count, 500);
    }

    function test_WhenRequestedEntriesEqualTheRemainingCapacity()
        external
        givenTheStakeCurrencyIsNative
        whenRequestedEntriesEqualTheRemainingCapacity
    {
        vm.expectEmit();
        emit IRips.RipEntered(ripId, user, entriesToBuy, 0);

        vm.prank(user);
        rips.enterRip{value: entriesToBuy * DEFAULT_ENTRY_PRICE}(stakeId, entriesToBuy, user);

        IRips.Rip memory rip = rips.exposed_rip(ripId);
        assertEq(rip.entriesSold, DEFAULT_ENTRY_CAP);
        assertEq(uint256(rip.vrfRequestStatus), uint256(IRips.VrfRequestStatus.NotRequested));
    }

    function test_GivenTheStakeIsNotDeleted()
        external
        givenTheStakeCurrencyIsNative
        whenRequestedEntriesEqualTheRemainingCapacity
    {
        // fill rip 1 completely
        vm.prank(user);
        rips.enterRip{value: entriesToBuy * DEFAULT_ENTRY_PRICE}(stakeId, entriesToBuy, user);
        ripId = rips.stakeIdToCurrentRipId(stakeId);

        // buying again triggers creation of rip 2
        uint256 expectedNewRipId = rips.exposed_nextRipId();

        vm.prank(user);
        rips.enterRip{value: DEFAULT_ENTRY_PRICE}(stakeId, 1, user);

        uint256 newActiveRip = rips.stakeIdToCurrentRipId(stakeId);
        assertEq(newActiveRip, expectedNewRipId);
        assertNotEq(newActiveRip, ripId);
    }

    function test_GivenTheStakeIsDeleted()
        external
        givenTheStakeCurrencyIsNative
        whenRequestedEntriesEqualTheRemainingCapacity
    {
        // fill rip 1 completely
        vm.prank(user);
        rips.enterRip{value: entriesToBuy * DEFAULT_ENTRY_PRICE}(stakeId, entriesToBuy, user);
        ripId = rips.stakeIdToCurrentRipId(stakeId);

        vm.prank(owner);
        rips.deleteStake(stakeId);

        // buying again on a sold-out deleted stake should revert — no new rip created
        vm.prank(user);
        vm.expectRevert(IRips.StakeNotExist.selector);
        rips.enterRip{value: DEFAULT_ENTRY_PRICE}(stakeId, 1, user);

        // mapping still points to the sold-out rip, not a new one
        assertEq(rips.stakeIdToCurrentRipId(stakeId), ripId);
    }

    function test_WhenRequestedEntriesExceedAvailableEntries()
        external
        givenTheStakeCurrencyIsNative
    {
        uint64 initialBuy = DEFAULT_ENTRY_CAP - 1;
        vm.prank(user);
        rips.enterRip{value: initialBuy * DEFAULT_ENTRY_PRICE}(stakeId, initialBuy, user);

        entriesToBuy = 3;
        uint64 availableEntries = DEFAULT_ENTRY_CAP - initialBuy;
        uint256 payment = entriesToBuy * DEFAULT_ENTRY_PRICE;
        uint256 expectedRefund = (entriesToBuy - availableEntries) * DEFAULT_ENTRY_PRICE;

        uint256 balanceBefore = user.balance;

        vm.expectEmit();
        emit IRips.RipEntered(ripId, user, availableEntries, initialBuy);

        vm.prank(user);
        rips.enterRip{value: payment}(stakeId, entriesToBuy, user);

        IRips.Rip memory rip = rips.exposed_rip(ripId);
        assertEq(rip.entriesSold, DEFAULT_ENTRY_CAP);
        assertEq(uint256(rip.vrfRequestStatus), uint256(IRips.VrfRequestStatus.NotRequested));

        assertEq(user.balance, balanceBefore - payment + expectedRefund);
    }

    modifier givenTheStakeCurrencyIsAnERC20Token() {
        stakeId = _createDefaultERC20Stake();
        _mintAndApprove(user, 100 ether);
        // ripId is set after first enterRip since rip is created lazily
        ripId = rips.exposed_nextRipId();
        _;
    }

    function test_RevertWhen_ETHIsSent() external givenTheStakeCurrencyIsAnERC20Token {
        vm.prank(user);
        vm.expectRevert(IRips.EthSentForERC20.selector);
        rips.enterRip{value: 1}(stakeId, 1, user);
    }

    function test_WhenRequestedEntriesAreFewerThanAvailable()
        external
        givenTheStakeCurrencyIsAnERC20Token
        whenRequestedEntriesAreFewerThanAvailable
    {
        uint256 expectedCost = entriesToBuy * DEFAULT_ENTRY_PRICE;
        uint256 balanceBefore = erc20.balanceOf(user);

        vm.expectEmit();
        emit IRips.RipEntered(ripId, user, entriesToBuy, 0);

        vm.prank(user);
        rips.enterRip(stakeId, entriesToBuy, user);

        assertEq(erc20.balanceOf(user), balanceBefore - expectedCost);

        IRips.Rip memory rip = rips.exposed_rip(ripId);
        assertEq(rip.entriesSold, entriesToBuy);

        IRips.EntryRange[] memory ranges = rips.getUserEntries(ripId, user);
        assertEq(ranges.length, 1);
        assertEq(ranges[0].count, entriesToBuy);
    }

    function test_WhenRecipientIsDifferentFromTheCaller_GivenERC20()
        external
        givenTheStakeCurrencyIsAnERC20Token
        whenRequestedEntriesAreFewerThanAvailable
    {
        address recipient = makeAddr("recipient");

        vm.prank(user);
        rips.enterRip(stakeId, entriesToBuy, recipient);

        IRips.EntryRange[] memory recipientRanges = rips.getUserEntries(ripId, recipient);
        assertEq(recipientRanges.length, 1);
        assertEq(recipientRanges[0].count, entriesToBuy);

        IRips.EntryRange[] memory callerRanges = rips.getUserEntries(ripId, user);
        assertEq(callerRanges.length, 0);
    }

    function test_WhenEntryCountExceedsMAX_ENTRIES_PER_RANGE_GivenERC20()
        external
        givenTheStakeCurrencyIsAnERC20Token
        whenRequestedEntriesAreFewerThanAvailable
    {
        uint64 largeEntryCap = 2048;
        uint256 entryPrice = 0.01 ether;

        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](1);
        tiers[0] = IRips.PayoutTier({
            payoutCount: largeEntryCap,
            minPayout: uint128(entryPrice),
            maxPayout: uint128(entryPrice)
        });

        vm.prank(owner);
        uint64 largeStakeId = rips.createStake(
            IRips.Config({
                currency: address(erc20),
                tiers: tiers,
                entryCap: largeEntryCap,
                duration: DEFAULT_DURATION,
                entryPrice: entryPrice,
                feePercent: 0
            })
        );

        entriesToBuy = 1500;

        vm.prank(user);
        rips.enterRip(largeStakeId, entriesToBuy, user);

        uint256 largeRipId = rips.stakeIdToCurrentRipId(largeStakeId);
        IRips.EntryRange[] memory ranges = rips.getUserEntries(largeRipId, user);
        assertEq(ranges.length, 2);
        assertEq(ranges[0].count, 1000);
        assertEq(ranges[1].count, 500);
    }

    function test_WhenRequestedEntriesEqualTheRemainingCapacity_GivenERC20()
        external
        givenTheStakeCurrencyIsAnERC20Token
        whenRequestedEntriesEqualTheRemainingCapacity
    {
        uint256 expectedCost = DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE;
        uint256 balanceBefore = erc20.balanceOf(user);

        vm.expectEmit();
        emit IRips.RipEntered(ripId, user, entriesToBuy, 0);

        vm.prank(user);
        rips.enterRip(stakeId, entriesToBuy, user);

        assertEq(erc20.balanceOf(user), balanceBefore - expectedCost);

        IRips.Rip memory rip = rips.exposed_rip(ripId);
        assertEq(rip.entriesSold, DEFAULT_ENTRY_CAP);
        assertEq(uint256(rip.vrfRequestStatus), uint256(IRips.VrfRequestStatus.NotRequested));
    }

    function test_WhenRequestedEntriesExceedAvailableEntries_GivenERC20()
        external
        givenTheStakeCurrencyIsAnERC20Token
    {
        uint64 initialBuy = DEFAULT_ENTRY_CAP - 1;
        vm.prank(user);
        rips.enterRip(stakeId, initialBuy, user);

        entriesToBuy = 3;
        uint64 availableEntries = DEFAULT_ENTRY_CAP - initialBuy;
        uint256 expectedCost = availableEntries * DEFAULT_ENTRY_PRICE;
        uint256 balanceBefore = erc20.balanceOf(user);

        vm.expectEmit();
        emit IRips.RipEntered(ripId, user, availableEntries, initialBuy);

        vm.prank(user);
        rips.enterRip(stakeId, entriesToBuy, user);

        assertEq(erc20.balanceOf(user), balanceBefore - expectedCost);

        IRips.Rip memory rip = rips.exposed_rip(ripId);
        assertEq(rip.entriesSold, DEFAULT_ENTRY_CAP);
        assertEq(uint256(rip.vrfRequestStatus), uint256(IRips.VrfRequestStatus.NotRequested));
    }
}
