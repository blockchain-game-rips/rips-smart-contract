// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract Rips_WithdrawProtocolFee is RipsTestBase {
    uint16 private constant FEE_PERCENT = 500;
    uint256 private constant PAYOUT_PER_ENTRY = 0.95 ether;

    uint256 private ripId;

    function setUp() public override {
        super.setUp();

        vrfCoordinator.fundSubscription(vrfSubscriptionId, 100 ether);

        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](1);
        tiers[0] = IRips.PayoutTier({
            payoutCount: uint64(DEFAULT_ENTRY_CAP),
            minPayout: uint128(PAYOUT_PER_ENTRY),
            maxPayout: uint128(PAYOUT_PER_ENTRY)
        });

        vm.prank(owner);
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

        vm.deal(user, DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE);
        vm.prank(user);
        rips.enterRip{value: DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE}(presetId, DEFAULT_ENTRY_CAP, user);

        ripId = rips.presetIdToCurrentRipId(presetId);
        uint256 vrfRequestId = rips.requestRandomness(ripId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));

        vm.prank(user);
        rips.claimPayout(ripId, 10, user, address(0));
    }

    function _protocolFee() private pure returns (uint256) {
        return DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE * FEE_PERCENT / 10_000;
    }

    function test_RevertWhen_TheCallerHasNeitherAdminNorOperatorRole() external {
        // it should revert.
        vm.prank(user);
        vm.expectRevert();
        rips.withdrawProtocolFee(address(0));
    }

    function test_RevertWhen_ThereIsNoAccruedFeeForTheCurrency() external {
        // it should revert.
        vm.prank(owner);
        vm.expectRevert(IRips.NothingToWithdraw.selector);
        rips.withdrawProtocolFee(address(erc20));
    }

    function test_WhenThereIsAccruedFeeForTheCurrency() external {
        // it should reset the accrued fee to zero.
        // it should transfer the fee to the fee recipient.
        // it should emit a {ProtocolFeeWithdrawn} event.
        uint256 feeRecipientBalanceBefore = owner.balance;

        vm.expectEmit();
        emit IRips.ProtocolFeeWithdrawn(owner, address(0), _protocolFee());

        vm.prank(owner);
        rips.withdrawProtocolFee(address(0));

        assertEq(rips.protocolFeeAccrued(address(0)), 0);
        assertEq(owner.balance, feeRecipientBalanceBefore + _protocolFee());
    }

    function test_WhenTheCallerHasOperatorRole() external {
        // when the caller has operator role
        // it should succeed.
        vm.startPrank(owner);
        rips.grantRole(rips.OPERATOR_ROLE(), operator);
        vm.stopPrank();

        uint256 feeRecipientBalanceBefore = owner.balance;

        vm.prank(operator);
        rips.withdrawProtocolFee(address(0));

        assertEq(rips.protocolFeeAccrued(address(0)), 0);
        assertEq(owner.balance, feeRecipientBalanceBefore + _protocolFee());
    }
}
