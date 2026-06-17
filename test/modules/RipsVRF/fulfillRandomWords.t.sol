// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";
import "../../../src/libraries/RipsMath.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

contract Rips_FulfillRandomWords is RipsTestBase {
    event RandomnessFulfilled(uint256 indexed ripId, uint256 randomA, uint256 randomB);

    uint64 private constant ENTRY_CAP = 2;
    uint256 private constant ENTRY_PRICE = 1 ether;

    uint64 private stakeId;
    uint256 private ripId;
    uint256 private vrfRequestId;

    function setUp() public override {
        super.setUp();

        vrfCoordinator.fundSubscription(vrfSubscriptionId, 100 ether);

        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](1);
        tiers[0] = IRips.PayoutTier({
            payoutCount: uint64(ENTRY_CAP),
            minPayout: uint128(ENTRY_PRICE),
            maxPayout: uint128(ENTRY_PRICE)
        });

        vm.prank(owner);
        stakeId = rips.createStake(
            IRips.Config({
                currency: address(0),
                tiers: tiers,
                entryCap: ENTRY_CAP,
                duration: 1 days,
                entryPrice: ENTRY_PRICE,
                feePercent: 0
            })
        );

        vm.deal(user, ENTRY_CAP * ENTRY_PRICE);
        vm.prank(user);
        rips.enterRip{value: ENTRY_CAP * ENTRY_PRICE}(stakeId, ENTRY_CAP, user);

        ripId = rips.stakeIdToCurrentRipId(stakeId);
        vrfRequestId = rips.requestRandomness(ripId);
    }

    uint256 private constant VRF_EXPIRY = 7 weeks;

    function test_RevertWhen_CalledByAnAddressThatIsNotTheVRFCoordinator() external {
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;

        bytes32 coordinatorRole = rips.VRF_COORDINATOR_ROLE();

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, user, coordinatorRole
            )
        );
        rips.rawFulfillRandomWords(vrfRequestId, randomWords);
    }

    function test_RevertWhen_TheRequestIdDoesNotMapToARip() external {
        uint256 unknownRequestId = 999;
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;

        vm.prank(address(vrfCoordinator));
        vm.expectRevert(IRips.RipNotExist.selector);
        rips.rawFulfillRandomWords(unknownRequestId, randomWords);
    }

    function test_RevertWhen_TheVrfRequestStatusIsNotRequested() external {
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;

        vm.prank(address(vrfCoordinator));
        vm.expectRevert(IRips.InvalidVrfRequestStatus.selector);
        rips.rawFulfillRandomWords(vrfRequestId, randomWords);
    }

    function test_RevertWhen_TheVRFRequestIsExpired() external {
        vm.warp(block.timestamp + VRF_EXPIRY + 1);

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;

        vm.prank(address(vrfCoordinator));
        vm.expectRevert(IRips.RipExpired.selector);
        rips.rawFulfillRandomWords(vrfRequestId, randomWords);
    }

    function test_WhenCalledByTheVRFCoordinator() external {
        uint256 randomWord = uint256(keccak256(abi.encode(vrfRequestId, uint256(0))));
        uint256 expectedA = RipsMath.deriveCoprimeA(randomWord, ENTRY_CAP);
        uint256 expectedB = uint256(keccak256(abi.encode(randomWord))) % ENTRY_CAP;

        vm.expectEmit(true, false, false, true);
        emit RandomnessFulfilled(ripId, expectedA, expectedB);

        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));

        IRips.Rip memory rip = rips.exposed_rip(ripId);
        assertEq(rip.randomA, expectedA);
        assertEq(rip.randomB, expectedB);
        assertEq(uint8(rip.vrfRequestStatus), uint8(IRips.VrfRequestStatus.Fulfilled));
    }
}
