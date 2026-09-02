// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";

contract Rips_ClaimPayout is RipsTestBase {
    uint256 private constant MAX_CHUNKS = 10;
    uint16 private constant FEE_BASE = 10_000;
    uint16 private constant FEE_PERCENT = 500;
    uint256 private constant FEE_PAYOUT_PER_ENTRY = 0.95 ether;

    uint16 private constant FULL_FEE_PERCENT = FEE_BASE;
    uint128 private constant ZERO_PAYOUT = 0;

    uint64 private presetId;
    uint256 private ripId;

    function setUp() public override {
        super.setUp();

        vrfCoordinator.fundSubscription(vrfSubscriptionId, 100 ether);

        presetId = _createDefaultPreset();

        vm.deal(user, 100 ether);
        vm.prank(user);
        rips.enterRip{value: DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE}(
            presetId, DEFAULT_ENTRY_CAP, user
        );

        ripId = rips.presetIdToCurrentRipId(presetId);
    }

    function _finalizeRip() private {
        uint256 vrfRequestId = rips.requestRandomness(ripId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));
    }

    function _totalPayout() private pure returns (uint256) {
        return DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE;
    }

    function _feePayoutPool() private pure returns (uint256) {
        return DEFAULT_ENTRY_CAP * FEE_PAYOUT_PER_ENTRY;
    }

    function _protocolFee() private pure returns (uint256) {
        return DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE * FEE_PERCENT / FEE_BASE;
    }

    function _createFeeNativePreset() private returns (uint256 feeRipId) {
        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](1);
        tiers[0] = IRips.PayoutTier({
            payoutCount: uint64(DEFAULT_ENTRY_CAP),
            minPayout: uint128(FEE_PAYOUT_PER_ENTRY),
            maxPayout: uint128(FEE_PAYOUT_PER_ENTRY)
        });

        vm.prank(owner);
        uint64 feePresetId = rips.createPreset(
            IRips.Config({
                currency: address(0),
                tiers: tiers,
                entryCap: DEFAULT_ENTRY_CAP,
                duration: DEFAULT_DURATION,
                entryPrice: DEFAULT_ENTRY_PRICE,
                feeBps: FEE_PERCENT
            })
        );

        vm.prank(user);
        rips.enterRip{value: DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE}(
            feePresetId, DEFAULT_ENTRY_CAP, user
        );

        feeRipId = rips.presetIdToCurrentRipId(feePresetId);
        uint256 vrfRequestId = rips.requestRandomness(feeRipId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));
    }

    function _zeroPayoutEntryRevenue() private pure returns (uint256) {
        return DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE;
    }

    function _zeroPayoutProtocolFee() private pure returns (uint256) {
        return _zeroPayoutEntryRevenue() * FULL_FEE_PERCENT / FEE_BASE;
    }

    function _createZeroPayoutPreset() private returns (uint256 zeroPayoutRipId) {
        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](1);
        tiers[0] = IRips.PayoutTier({
            payoutCount: uint64(DEFAULT_ENTRY_CAP), minPayout: ZERO_PAYOUT, maxPayout: ZERO_PAYOUT
        });

        vm.prank(owner);
        uint64 zeroPayoutPresetId = rips.createPreset(
            IRips.Config({
                currency: address(0),
                tiers: tiers,
                entryCap: DEFAULT_ENTRY_CAP,
                duration: DEFAULT_DURATION,
                entryPrice: DEFAULT_ENTRY_PRICE,
                feeBps: FULL_FEE_PERCENT
            })
        );

        vm.prank(user);
        rips.enterRip{value: DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE}(
            zeroPayoutPresetId, DEFAULT_ENTRY_CAP, user
        );

        zeroPayoutRipId = rips.presetIdToCurrentRipId(zeroPayoutPresetId);
        uint256 vrfRequestId = rips.requestRandomness(zeroPayoutRipId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));
    }

    function test_RevertWhen_TheRipIsNotFinalized() external {
        vm.prank(user);
        vm.expectRevert(IRips.RipNotFulfilled.selector);
        rips.claimPayout(ripId, MAX_CHUNKS, user, referrer);
    }

    function test_RevertWhen_RecipientIsZeroAddress() external {
        _finalizeRip();

        vm.prank(user);
        vm.expectRevert();
        rips.claimPayout(ripId, MAX_CHUNKS, address(0), referrer);
    }

    function test_RevertWhen_TheRecipientHasNoEntries() external {
        _finalizeRip();

        address stranger = makeAddr("stranger");

        vm.prank(stranger);
        vm.expectRevert(IRips.NothingToClaim.selector);
        rips.claimPayout(ripId, MAX_CHUNKS, stranger, referrer);
    }

    function test_RevertWhen_MaxChunksIsZero() external {
        _finalizeRip();

        vm.prank(user);
        vm.expectRevert(IRips.ZeroMaxChunks.selector);
        rips.claimPayout(ripId, 0, user, referrer);
    }

    function test_RevertWhen_EveryChunkIsAlreadyClaimed() external {
        _finalizeRip();

        vm.prank(user);
        rips.claimPayout(ripId, MAX_CHUNKS, user, referrer);

        vm.prank(user);
        vm.expectRevert(IRips.NothingToClaim.selector);
        rips.claimPayout(ripId, MAX_CHUNKS, user, referrer);
    }

    modifier whenThereAreUnclaimedChunks() {
        _finalizeRip();
        _;
    }

    function test_WhenThereAreUnclaimedChunks_AdvancesTheCursorPastEveryChunk()
        external
        whenThereAreUnclaimedChunks
    {
        vm.prank(user);
        rips.claimPayout(ripId, MAX_CHUNKS, user, referrer);

        IRips.EntryChunk[] memory chunks = rips.getUserEntries(ripId, user);
        assertEq(rips.nextClaimChunkIndex(ripId, user), chunks.length);
    }

    function test_WhenThereAreUnclaimedChunks_CalculatesCorrectPayouts()
        external
        whenThereAreUnclaimedChunks
    {
        uint256 balanceBefore = user.balance;

        vm.prank(user);
        rips.claimPayout(ripId, MAX_CHUNKS, user, referrer);

        assertEq(user.balance, balanceBefore + _totalPayout());
    }

    function test_WhenEveryClaimedEntryHasZeroPayout() external {
        uint256 zeroPayoutRipId = _createZeroPayoutPreset();

        uint256 userBalanceBefore = user.balance;

        vm.prank(user);
        rips.claimPayout(zeroPayoutRipId, MAX_CHUNKS, user, referrer);

        assertEq(user.balance, userBalanceBefore, "recipient should receive no payout");

        assertEq(
            rips.protocolFeeAccrued(address(0)),
            _zeroPayoutProtocolFee(),
            "protocol fee should be accrued for zero-payout entries"
        );

        IRips.EntryChunk[] memory chunks = rips.getUserEntries(zeroPayoutRipId, user);
        assertEq(
            rips.nextClaimChunkIndex(zeroPayoutRipId, user),
            chunks.length,
            "cursor should advance past every chunk"
        );

        IRips.ReferrerState memory referrerState = rips.exposed_referrerStats(referrer, address(0));
        assertEq(
            referrerState.periodVolume,
            _zeroPayoutEntryRevenue(),
            "referrer period volume should be credited"
        );
    }

    function test_RevertWhen_CallerIsNotTheRecipientAndHasNeitherAdminNorOperatorRole()
        external
        whenThereAreUnclaimedChunks
    {
        address caller = makeAddr("caller");

        vm.prank(caller);
        vm.expectRevert(IRips.NotRecipientOrOwner.selector);
        rips.claimPayout(ripId, MAX_CHUNKS, user, referrer);
    }

    function test_WhenCallerHasAdminRoleAndRecipientIsADifferentAddress()
        external
        whenThereAreUnclaimedChunks
    {
        uint256 recipientBalanceBefore = user.balance;
        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(owner);
        rips.claimPayout(ripId, MAX_CHUNKS, user, referrer);

        assertEq(user.balance, recipientBalanceBefore + _totalPayout());
        assertEq(owner.balance, ownerBalanceBefore);
    }

    function test_WhenCallerHasOperatorRoleAndRecipientIsADifferentAddress()
        external
        whenThereAreUnclaimedChunks
    {
        vm.startPrank(owner);
        rips.grantRole(rips.OPERATOR_ROLE(), operator);
        vm.stopPrank();

        uint256 recipientBalanceBefore = user.balance;
        uint256 operatorBalanceBefore = operator.balance;

        vm.prank(operator);
        rips.claimPayout(ripId, MAX_CHUNKS, user, referrer);

        assertEq(user.balance, recipientBalanceBefore + _totalPayout());
        //TODO: unnecessary assert, check Rips smart contract balance
        assertEq(operator.balance, operatorBalanceBefore);
    }

    modifier givenThePresetCurrencyIsNative() {
        _;
    }

    function test_WhenProtocolFeeIsZero()
        external
        whenThereAreUnclaimedChunks
        givenThePresetCurrencyIsNative
    {
        uint256 balanceBefore = user.balance;

        vm.expectEmit();
        emit IRips.PayoutClaimed(ripId, user, referrer, DEFAULT_ENTRY_CAP, _totalPayout());

        vm.prank(user);
        rips.claimPayout(ripId, MAX_CHUNKS, user, referrer);

        assertEq(user.balance, balanceBefore + _totalPayout());
    }

    function test_WhenProtocolFeeIsGreaterThanZero()
        external
        whenThereAreUnclaimedChunks
        givenThePresetCurrencyIsNative
    {
        uint256 feeRipId = _createFeeNativePreset();

        uint256 userBalanceBefore = user.balance;

        vm.expectEmit();
        emit IRips.ProtocolFeeAccrued(feeRipId, _protocolFee());

        vm.expectEmit();
        emit IRips.PayoutClaimed(feeRipId, user, referrer, DEFAULT_ENTRY_CAP, _feePayoutPool());

        vm.prank(user);
        rips.claimPayout(feeRipId, MAX_CHUNKS, user, referrer);

        assertEq(user.balance, userBalanceBefore + _feePayoutPool());
        assertEq(rips.protocolFeeAccrued(address(0)), _protocolFee());
    }

    function test_WhenProtocolFeeIsZero_GivenThePresetCurrencyIsAnERC20Token() external {
        _mintAndApprove(user, DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE);

        uint64 erc20PresetId = _createDefaultERC20Preset();

        vm.prank(user);
        rips.enterRip(erc20PresetId, DEFAULT_ENTRY_CAP, user);

        uint256 erc20RipId = rips.presetIdToCurrentRipId(erc20PresetId);
        uint256 vrfRequestId = rips.requestRandomness(erc20RipId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));

        uint256 balanceBefore = erc20.balanceOf(user);

        vm.expectEmit();
        emit IRips.PayoutClaimed(erc20RipId, user, referrer, DEFAULT_ENTRY_CAP, _totalPayout());

        vm.prank(user);
        rips.claimPayout(erc20RipId, MAX_CHUNKS, user, referrer);

        assertEq(erc20.balanceOf(user), balanceBefore + _totalPayout());
    }

    function test_WhenProtocolFeeIsGreaterThanZero_GivenThePresetCurrencyIsAnERC20Token() external {
        _mintAndApprove(user, DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE);

        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](1);
        tiers[0] = IRips.PayoutTier({
            payoutCount: uint64(DEFAULT_ENTRY_CAP),
            minPayout: uint128(FEE_PAYOUT_PER_ENTRY),
            maxPayout: uint128(FEE_PAYOUT_PER_ENTRY)
        });

        vm.prank(owner);
        uint64 feePresetId = rips.createPreset(
            IRips.Config({
                currency: address(erc20),
                tiers: tiers,
                entryCap: DEFAULT_ENTRY_CAP,
                duration: DEFAULT_DURATION,
                entryPrice: DEFAULT_ENTRY_PRICE,
                feeBps: FEE_PERCENT
            })
        );

        vm.prank(user);
        rips.enterRip(feePresetId, DEFAULT_ENTRY_CAP, user);

        uint256 feeRipId = rips.presetIdToCurrentRipId(feePresetId);
        uint256 vrfRequestId = rips.requestRandomness(feeRipId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));

        uint256 userBalanceBefore = erc20.balanceOf(user);

        vm.expectEmit();
        emit IRips.ProtocolFeeAccrued(feeRipId, _protocolFee());

        vm.expectEmit();
        emit IRips.PayoutClaimed(feeRipId, user, referrer, DEFAULT_ENTRY_CAP, _feePayoutPool());

        vm.prank(user);
        rips.claimPayout(feeRipId, MAX_CHUNKS, user, referrer);

        assertEq(erc20.balanceOf(user), userBalanceBefore + _feePayoutPool());
        assertEq(rips.protocolFeeAccrued(address(erc20)), _protocolFee());
    }
}
