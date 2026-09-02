// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";
import {RipsConduit} from "../../src/RipsConduit.sol";

contract RipsConduit_EnterRip is RipsTestBase {
    RipsConduit internal conduit;

    address internal bridge = makeAddr("bridge");
    address internal recipient = makeAddr("recipient");

    uint64 private presetId;
    uint256 private ripId;

    function setUp() public override {
        super.setUp();

        conduit = new RipsConduit(address(rips));

        presetId = _createDefaultPreset();
        ripId = rips.exposed_nextRipId(); // rip is created lazily on first enterRip

        vm.deal(bridge, 100 ether);
    }

    function test_WhenThePaymentCoversEveryRequestedEntry() external {
        uint64 entriesToBuy = 2;

        vm.prank(bridge);
        conduit.enterRip{value: entriesToBuy * DEFAULT_ENTRY_PRICE}(presetId, entriesToBuy, recipient);

        assertEq(rips.userEntryCount(ripId, recipient), entriesToBuy);
        assertEq(address(conduit).balance, 0);
        assertEq(recipient.balance, 0);
    }

    function test_WhenRequestedEntriesExceedAvailableEntries() external {
        uint64 requestedEntries = DEFAULT_ENTRY_CAP + 4;
        uint256 payment = requestedEntries * DEFAULT_ENTRY_PRICE;
        uint256 expectedExcess = payment - DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE;

        vm.expectEmit(address(conduit));
        emit RipsConduit.ExcessForwarded(recipient, expectedExcess);

        vm.prank(bridge);
        conduit.enterRip{value: payment}(presetId, requestedEntries, recipient);

        assertEq(rips.userEntryCount(ripId, recipient), DEFAULT_ENTRY_CAP);
        assertEq(recipient.balance, expectedExcess);
        assertEq(address(conduit).balance, 0);
    }

    function test_WhenTheConduitHoldsAStrandedBalance() external {
        uint256 strandedBalance = 3 ether;
        vm.deal(address(conduit), strandedBalance);

        uint64 requestedEntries = DEFAULT_ENTRY_CAP + 1;
        uint256 payment = requestedEntries * DEFAULT_ENTRY_PRICE;
        uint256 excess = payment - DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE;

        vm.prank(bridge);
        conduit.enterRip{value: payment}(presetId, requestedEntries, recipient);

        assertEq(recipient.balance, excess + strandedBalance);
        assertEq(address(conduit).balance, 0);
    }

    function test_RevertWhen_TheRecipientRejectsNativeCurrency() external {
        address rejector = address(new NativeRejector());

        uint64 requestedEntries = DEFAULT_ENTRY_CAP + 1;

        vm.prank(bridge);
        vm.expectRevert(RipsConduit.TransferFailed.selector);
        conduit.enterRip{value: requestedEntries * DEFAULT_ENTRY_PRICE}(presetId, requestedEntries, rejector);
    }
}

/// @dev Has no receive function, so a plain native transfer to it fails.
contract NativeRejector {}
