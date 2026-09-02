// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract Rips_SeizeReferrerFee is RipsTestBase {
    uint16 private constant FEE_PERCENT = 500;
    uint16 private constant REFERRER_FEE_PERCENT = 2000;
    uint256 private constant PAYOUT_PER_ENTRY = 0.95 ether;

    function setUp() public override {
        super.setUp();

        vrfCoordinator.fundSubscription(vrfSubscriptionId, 100 ether);

        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](1);
        tiers[0] = IRips.PayoutTier({
            payoutCount: uint64(DEFAULT_ENTRY_CAP),
            minPayout: uint128(PAYOUT_PER_ENTRY),
            maxPayout: uint128(PAYOUT_PER_ENTRY)
        });

        vm.startPrank(owner);
        uint64 presetId = rips.createPreset(
            IRips.Config({
                currency: address(0),
                tiers: tiers,
                entryCap: DEFAULT_ENTRY_CAP,
                duration: DEFAULT_DURATION,
                entryPrice: DEFAULT_ENTRY_PRICE,
                feeBps: FEE_PERCENT
            })
        );
        rips.setReferrerCustomFee(referrer, REFERRER_FEE_PERCENT);
        vm.stopPrank();

        vm.deal(user, DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE);
        vm.prank(user);
        rips.enterRip{value: DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE}(
            presetId, DEFAULT_ENTRY_CAP, user
        );

        uint256 ripId = rips.presetIdToCurrentRipId(presetId);
        uint256 vrfRequestId = rips.requestRandomness(ripId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));

        vm.prank(user);
        rips.claimPayout(ripId, 10, user, referrer);
    }

    function _protocolFee() private pure returns (uint256) {
        return DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE * FEE_PERCENT / 10_000;
    }

    function _referrerFee() private pure returns (uint256) {
        return _protocolFee() * REFERRER_FEE_PERCENT / 10_000;
    }

    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        // it should revert.
        vm.prank(user);
        vm.expectRevert();
        rips.seizeReferrerFee(referrer, address(0));
    }

    function test_RevertWhen_TheReferrerIsTheZeroAddress() external {
        // it should revert.
        vm.prank(owner);
        vm.expectRevert(IRips.ZeroAddress.selector);
        rips.seizeReferrerFee(address(0), address(0));
    }

    function test_RevertWhen_ThereIsNoAccruedFeeForTheReferrerAndCurrency() external {
        // it should revert.
        address otherReferrer = makeAddr("otherReferrer");
        vm.prank(owner);
        vm.expectRevert(IRips.NothingToWithdraw.selector);
        rips.seizeReferrerFee(otherReferrer, address(0));
    }

    function test_WhenThereIsAccruedFeeForTheReferrerAndCurrency() external {
        // it should reset the accrued fee to zero.
        // it should transfer the fee to the fee recipient.
        // it should emit a {ReferrerFeeSeized} event.
        uint256 feeRecipientBalanceBefore = owner.balance;

        vm.expectEmit();
        emit IRips.ReferrerFeeSeized(referrer, address(0), _referrerFee());

        vm.prank(owner);
        rips.seizeReferrerFee(referrer, address(0));

        assertEq(rips.referrerFeeAccrued(referrer, address(0)), 0);
        assertEq(owner.balance, feeRecipientBalanceBefore + _referrerFee());
    }
}
