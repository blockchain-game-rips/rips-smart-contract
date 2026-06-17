// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";

contract Rips_ClaimPayout is RipsTestBase {
    uint256 private constant START_INDEX = 0;
    uint256 private constant MAX_RANGES = 10;
    uint16 private constant FEE_PERCENT = 500;
    uint256 private constant FEE_PAYOUT_PER_ENTRY = 0.95 ether;

    uint64 private stakeId;
    uint256 private ripId;

    function setUp() public override {
        super.setUp();

        vrfCoordinator.fundSubscription(vrfSubscriptionId, 100 ether);

        stakeId = _createDefaultStake();

        vm.deal(user, 100 ether);
        vm.prank(user);
        rips.enterRip{value: DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE}(
            stakeId, DEFAULT_ENTRY_CAP, user
        );

        ripId = rips.stakeIdToCurrentRipId(stakeId);
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
        return DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE * FEE_PERCENT / 10_000;
    }

    function _createFeeNativeStake() private returns (uint256 feeRipId) {
        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](1);
        tiers[0] = IRips.PayoutTier({
            payoutCount: uint64(DEFAULT_ENTRY_CAP),
            minPayout: uint128(FEE_PAYOUT_PER_ENTRY),
            maxPayout: uint128(FEE_PAYOUT_PER_ENTRY)
        });

        vm.prank(owner);
        uint64 feeStakeId = rips.createStake(
            IRips.Config({
                currency: address(0),
                tiers: tiers,
                entryCap: DEFAULT_ENTRY_CAP,
                duration: DEFAULT_DURATION,
                entryPrice: DEFAULT_ENTRY_PRICE,
                feePercent: FEE_PERCENT
            })
        );

        vm.prank(user);
        rips.enterRip{value: DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE}(
            feeStakeId, DEFAULT_ENTRY_CAP, user
        );

        feeRipId = rips.stakeIdToCurrentRipId(feeStakeId);
        uint256 vrfRequestId = rips.requestRandomness(feeRipId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));
    }

    function test_RevertWhen_TheRipIsNotFinalized() external {
        vm.prank(user);
        vm.expectRevert(IRips.RipNotFulfilled.selector);
        rips.claimPayout(ripId, START_INDEX, MAX_RANGES, user, referrer);
    }

    function test_RevertWhen_RecipientIsZeroAddress() external {
        _finalizeRip();

        vm.prank(user);
        vm.expectRevert();
        rips.claimPayout(ripId, START_INDEX, MAX_RANGES, address(0), referrer);
    }

    function test_RevertWhen_StartIndexIsOutOfBounds() external {
        _finalizeRip();

        IRips.EntryRange[] memory ranges = rips.getUserEntries(ripId, user);
        uint256 outOfBoundsIndex = ranges.length;

        vm.prank(user);
        vm.expectRevert(IRips.InvalidStartIndex.selector);
        rips.claimPayout(ripId, outOfBoundsIndex, MAX_RANGES, user, referrer);
    }

    function test_WhenAllRangesInScopeAreAlreadyClaimed() external {
        _finalizeRip();

        vm.prank(user);
        rips.claimPayout(ripId, START_INDEX, MAX_RANGES, user, referrer);

        uint256 balanceBefore = user.balance;

        vm.prank(user);
        rips.claimPayout(ripId, START_INDEX, MAX_RANGES, user, referrer);

        assertEq(user.balance, balanceBefore);
    }

    modifier whenThereAreUnclaimedRanges() {
        _finalizeRip();
        _;
    }

    function test_WhenThereAreUnclaimedRanges_MarksRangesAsClaimed()
        external
        whenThereAreUnclaimedRanges
    {
        vm.prank(user);
        rips.claimPayout(ripId, START_INDEX, MAX_RANGES, user, referrer);

        IRips.EntryRange[] memory ranges = rips.getUserEntries(ripId, user);
        for (uint256 i = 0; i < ranges.length; i++) {
            assertTrue(ranges[i].claimed);
        }
    }

    function test_WhenThereAreUnclaimedRanges_CalculatesCorrectPayouts()
        external
        whenThereAreUnclaimedRanges
    {
        uint256 balanceBefore = user.balance;

        vm.prank(user);
        rips.claimPayout(ripId, START_INDEX, MAX_RANGES, user, referrer);

        assertEq(user.balance, balanceBefore + _totalPayout());
    }

    function test_RevertWhen_CallerIsNotTheRecipientAndHasNeitherAdminNorOperatorRole()
        external
        whenThereAreUnclaimedRanges
    {
        address caller = makeAddr("caller");

        vm.prank(caller);
        vm.expectRevert(IRips.NotRecipientOrOwner.selector);
        rips.claimPayout(ripId, START_INDEX, MAX_RANGES, user, referrer);
    }

    function test_WhenCallerHasAdminRoleAndRecipientIsADifferentAddress()
        external
        whenThereAreUnclaimedRanges
    {
        uint256 recipientBalanceBefore = user.balance;
        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(owner);
        rips.claimPayout(ripId, START_INDEX, MAX_RANGES, user, referrer);

        assertEq(user.balance, recipientBalanceBefore + _totalPayout());
        assertEq(owner.balance, ownerBalanceBefore);
    }

    function test_WhenCallerHasOperatorRoleAndRecipientIsADifferentAddress()
        external
        whenThereAreUnclaimedRanges
    {
        vm.startPrank(owner);
        rips.grantRole(rips.OPERATOR_ROLE(), operator);
        vm.stopPrank();

        uint256 recipientBalanceBefore = user.balance;
        uint256 operatorBalanceBefore = operator.balance;

        vm.prank(operator);
        rips.claimPayout(ripId, START_INDEX, MAX_RANGES, user, referrer);

        assertEq(user.balance, recipientBalanceBefore + _totalPayout());
        //TODO: unnecessary assert, check Rips smart contract balance
        assertEq(operator.balance, operatorBalanceBefore);
    }

    modifier givenTheStakeCurrencyIsNative() {
        _;
    }

    function test_WhenProtocolFeeIsZero()
        external
        whenThereAreUnclaimedRanges
        givenTheStakeCurrencyIsNative
    {
        uint256 balanceBefore = user.balance;

        vm.expectEmit();
        emit IRips.PayoutClaimed(ripId, user, referrer, DEFAULT_ENTRY_CAP, _totalPayout());

        vm.prank(user);
        rips.claimPayout(ripId, START_INDEX, MAX_RANGES, user, referrer);

        assertEq(user.balance, balanceBefore + _totalPayout());
    }

    function test_WhenProtocolFeeIsGreaterThanZero()
        external
        whenThereAreUnclaimedRanges
        givenTheStakeCurrencyIsNative
    {
        uint256 feeRipId = _createFeeNativeStake();

        uint256 userBalanceBefore = user.balance;

        vm.expectEmit();
        emit IRips.ProtocolFeeAccrued(feeRipId, _protocolFee());

        vm.expectEmit();
        emit IRips.PayoutClaimed(feeRipId, user, referrer, DEFAULT_ENTRY_CAP, _feePayoutPool());

        vm.prank(user);
        rips.claimPayout(feeRipId, START_INDEX, MAX_RANGES, user, referrer);

        assertEq(user.balance, userBalanceBefore + _feePayoutPool());
        assertEq(rips.protocolFeeAccrued(address(0)), _protocolFee());
    }

    function test_WhenProtocolFeeIsZero_GivenTheStakeCurrencyIsAnERC20Token() external {
        _mintAndApprove(user, DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE);

        uint64 erc20StakeId = _createDefaultERC20Stake();

        vm.prank(user);
        rips.enterRip(erc20StakeId, DEFAULT_ENTRY_CAP, user);

        uint256 erc20RipId = rips.stakeIdToCurrentRipId(erc20StakeId);
        uint256 vrfRequestId = rips.requestRandomness(erc20RipId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));

        uint256 balanceBefore = erc20.balanceOf(user);

        vm.expectEmit();
        emit IRips.PayoutClaimed(erc20RipId, user, referrer, DEFAULT_ENTRY_CAP, _totalPayout());

        vm.prank(user);
        rips.claimPayout(erc20RipId, START_INDEX, MAX_RANGES, user, referrer);

        assertEq(erc20.balanceOf(user), balanceBefore + _totalPayout());
    }

    function test_WhenProtocolFeeIsGreaterThanZero_GivenTheStakeCurrencyIsAnERC20Token() external {
        _mintAndApprove(user, DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE);

        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](1);
        tiers[0] = IRips.PayoutTier({
            payoutCount: uint64(DEFAULT_ENTRY_CAP),
            minPayout: uint128(FEE_PAYOUT_PER_ENTRY),
            maxPayout: uint128(FEE_PAYOUT_PER_ENTRY)
        });

        vm.prank(owner);
        uint64 feeStakeId = rips.createStake(
            IRips.Config({
                currency: address(erc20),
                tiers: tiers,
                entryCap: DEFAULT_ENTRY_CAP,
                duration: DEFAULT_DURATION,
                entryPrice: DEFAULT_ENTRY_PRICE,
                feePercent: FEE_PERCENT
            })
        );

        vm.prank(user);
        rips.enterRip(feeStakeId, DEFAULT_ENTRY_CAP, user);

        uint256 feeRipId = rips.stakeIdToCurrentRipId(feeStakeId);
        uint256 vrfRequestId = rips.requestRandomness(feeRipId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));

        uint256 userBalanceBefore = erc20.balanceOf(user);

        vm.expectEmit();
        emit IRips.ProtocolFeeAccrued(feeRipId, _protocolFee());

        vm.expectEmit();
        emit IRips.PayoutClaimed(feeRipId, user, referrer, DEFAULT_ENTRY_CAP, _feePayoutPool());

        vm.prank(user);
        rips.claimPayout(feeRipId, START_INDEX, MAX_RANGES, user, referrer);

        assertEq(erc20.balanceOf(user), userBalanceBefore + _feePayoutPool());
        assertEq(rips.protocolFeeAccrued(address(erc20)), _protocolFee());
    }
}
