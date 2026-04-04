// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";
import "../../../src/libraries/RipsMath.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";

contract Rips_FulfillRandomWords is RipsTestBase {
    event RoundFinalized(uint256 indexed roundId, uint256 randomA, uint256 randomB);

    uint64 private constant TICKET_CAP = 2;
    uint256 private constant TICKET_COST = 1 ether;

    uint256 private stakeId;
    uint256 private roundId;
    uint256 private vrfRequestId;

    function setUp() public override {
        super.setUp();

        vrfCoordinator.fundSubscription(vrfSubscriptionId, 100 ether);

        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: uint64(TICKET_CAP),
            minPrize: uint128(TICKET_COST),
            maxPrize: uint128(TICKET_COST)
        });

        vm.prank(owner);
        stakeId = rips.createStake(
            IRips.Config({
                currency: address(0),
                tiers: tiers,
                ticketCap: TICKET_CAP,
                duration: 1 days,
                ticketCost: TICKET_COST,
                feePercent: 0
            })
        );

        vm.deal(user, TICKET_CAP * TICKET_COST);
        vm.prank(user);
        rips.buyTickets{value: TICKET_CAP * TICKET_COST}(stakeId, TICKET_CAP, user);

        roundId = rips.stakeIdToCurrentRoundId(stakeId);
        vrfRequestId = rips.requestRandomness(roundId);
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

    function test_RevertWhen_TheRequestIdDoesNotMapToARound() external {
        uint256 unknownRequestId = 999;
        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;

        vm.prank(address(vrfCoordinator));
        vm.expectRevert(IRips.RoundNotExist.selector);
        rips.rawFulfillRandomWords(unknownRequestId, randomWords);
    }

    function test_RevertWhen_TheRoundStatusIsNotVRFRequested() external {
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;

        vm.prank(address(vrfCoordinator));
        vm.expectRevert(IRips.InvalidRoundStatus.selector);
        rips.rawFulfillRandomWords(vrfRequestId, randomWords);
    }

    function test_RevertWhen_TheVRFRequestIsExpired() external {
        vm.warp(block.timestamp + VRF_EXPIRY + 1);

        uint256[] memory randomWords = new uint256[](1);
        randomWords[0] = 12345;

        vm.prank(address(vrfCoordinator));
        vm.expectRevert(IRips.RoundExpired.selector);
        rips.rawFulfillRandomWords(vrfRequestId, randomWords);
    }

    function test_WhenCalledByTheVRFCoordinator() external {
        uint256 randomWord = uint256(keccak256(abi.encode(vrfRequestId, uint256(0))));
        uint256 expectedA = RipsMath.deriveCoprimeA(randomWord, TICKET_CAP);
        uint256 expectedB = uint256(keccak256(abi.encode(randomWord))) % TICKET_CAP;

        vm.expectEmit(true, false, false, true);
        emit RoundFinalized(roundId, expectedA, expectedB);

        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));

        IRips.Round memory round = rips.exposed_round(roundId);
        assertEq(round.randomA, expectedA);
        assertEq(round.randomB, expectedB);
        assertEq(uint8(round.status), uint8(IRips.RoundStatus.Finalized));
    }
}
