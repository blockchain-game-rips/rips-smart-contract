// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";

contract Rips_Refund is RipsTestBase {
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

    function _expectedRefundAmount() private pure returns (uint256) {
        return ENTRIES_BOUGHT * DEFAULT_ENTRY_PRICE;
    }

    function test_RevertWhen_TheRipDoesNotExist() external {
        uint256 nonExistentRipId = 999;

        vm.prank(user);
        vm.expectRevert(IRips.RipNotExist.selector);
        rips.refund(nonExistentRipId, user);
    }

    function test_RevertWhen_RecipientIsZeroAddress() external {
        vm.prank(user);
        vm.expectRevert();
        rips.refund(ripId, address(0));
    }

    uint256 private constant VRF_EXPIRY = 7 weeks;

    function test_RevertWhen_TheRipIsNotSoldOutButHasNotPassedItsDuration() external {
        vm.prank(user);
        vm.expectRevert(IRips.RipNotExpired.selector);
        rips.refund(ripId, user);
    }

    function test_RevertWhen_TheRipIsSoldOutAndTheVRFRequestHasNotExpired() external {
        vrfCoordinator.fundSubscription(vrfSubscriptionId, 100 ether);

        vm.deal(user, (DEFAULT_ENTRY_CAP - ENTRIES_BOUGHT) * DEFAULT_ENTRY_PRICE);
        vm.prank(user);
        rips.enterRip{value: (DEFAULT_ENTRY_CAP - ENTRIES_BOUGHT) * DEFAULT_ENTRY_PRICE}(
            presetId, DEFAULT_ENTRY_CAP - ENTRIES_BOUGHT, user
        );

        rips.requestRandomness(ripId);

        vm.warp(block.timestamp + VRF_EXPIRY - 1);

        vm.prank(user);
        vm.expectRevert(IRips.RipNotExpired.selector);
        rips.refund(ripId, user);
    }

    function test_RevertWhen_TheRecipientHasAlreadyBeenRefunded() external {
        vm.warp(block.timestamp + DEFAULT_DURATION + 1);

        vm.prank(user);
        rips.refund(ripId, user);

        vm.prank(user);
        vm.expectRevert(IRips.AlreadyRefunded.selector);
        rips.refund(ripId, user);
    }

    function test_RevertWhen_TheRecipientHasNoEntriesInTheRip() external {
        vm.warp(block.timestamp + DEFAULT_DURATION + 1);

        address noEntries = makeAddr("noEntries");

        vm.prank(noEntries);
        vm.expectRevert(IRips.NoEntriesToRefund.selector);
        rips.refund(ripId, noEntries);
    }

    modifier givenThePresetCurrencyIsNative() {
        _;
    }

    modifier whenTheRecipientHasEntriesInTheRip() {
        vm.warp(block.timestamp + DEFAULT_DURATION + 1);
        _;
    }

    function test_WhenTheRecipientHasEntriesInTheRip()
        external
        givenThePresetCurrencyIsNative
        whenTheRecipientHasEntriesInTheRip
    {
        uint256 balanceBefore = user.balance;

        vm.expectEmit();
        emit IRips.RefundIssued(ripId, user, ENTRIES_BOUGHT);

        vm.prank(user);
        rips.refund(ripId, user);

        assertEq(user.balance, balanceBefore + _expectedRefundAmount());
        assertTrue(rips.hasRefunded(ripId, user));
    }

    function test_WhenRecipientIsDifferentFromTheCaller()
        external
        givenThePresetCurrencyIsNative
        whenTheRecipientHasEntriesInTheRip
    {
        address caller = makeAddr("caller");

        uint256 recipientBalanceBefore = user.balance;
        uint256 callerBalanceBefore = caller.balance;

        vm.prank(caller);
        rips.refund(ripId, user);

        assertEq(user.balance, recipientBalanceBefore + _expectedRefundAmount());
        assertEq(caller.balance, callerBalanceBefore);
    }

    modifier givenThePresetCurrencyIsAnERC20Token() {
        _mintAndApprove(user, ENTRIES_BOUGHT * DEFAULT_ENTRY_PRICE);

        uint64 erc20PresetId = _createDefaultERC20Preset();

        vm.prank(user);
        rips.enterRip(erc20PresetId, ENTRIES_BOUGHT, user);

        ripId = rips.presetIdToCurrentRipId(erc20PresetId);

        vm.warp(block.timestamp + DEFAULT_DURATION + 1);
        _;
    }

    function test_WhenTheRecipientHasEntriesInTheRip_GivenERC20()
        external
        givenThePresetCurrencyIsAnERC20Token
    {
        uint256 balanceBefore = erc20.balanceOf(user);

        vm.expectEmit();
        emit IRips.RefundIssued(ripId, user, ENTRIES_BOUGHT);

        vm.prank(user);
        rips.refund(ripId, user);

        assertEq(erc20.balanceOf(user), balanceBefore + _expectedRefundAmount());
        assertTrue(rips.hasRefunded(ripId, user));
    }

    function test_WhenRecipientIsDifferentFromTheCaller_GivenERC20()
        external
        givenThePresetCurrencyIsAnERC20Token
    {
        address caller = makeAddr("caller");

        uint256 recipientBalanceBefore = erc20.balanceOf(user);
        uint256 callerBalanceBefore = erc20.balanceOf(caller);

        vm.prank(caller);
        rips.refund(ripId, user);

        assertEq(erc20.balanceOf(user), recipientBalanceBefore + _expectedRefundAmount());
        assertEq(erc20.balanceOf(caller), callerBalanceBefore);
    }
}
