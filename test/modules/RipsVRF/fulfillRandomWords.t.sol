// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";
import "../../../src/modules/RipsMath.sol";

contract Rips_FulfillRandomWords is RipsTestBase {
    event RoundFinalized(uint256 indexed roundId, uint256 randomA, uint256 randomB);

    uint256 private constant TICKET_CAP = 2;
    uint256 private constant TICKET_COST = 1 ether;

    uint256 private stakeId;
    uint256 private roundId;
    uint256 private vrfRequestId;

    function setUp() public override {
        super.setUp();

        vrfCoordinator.fundSubscription(vrfSubscriptionId, 100 ether);

        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] =
            IRips.PrizeTier({prizeCount: uint64(TICKET_CAP), minPrize: uint128(TICKET_COST), maxPrize: uint128(TICKET_COST)});

        vm.prank(owner);
        stakeId = rips.createStake(
            IRips.StakeConfig({
                prizeDistribution: tiers,
                ticketCap: TICKET_CAP,
                duration: 1 days,
                ticketCost: TICKET_COST
            })
        );

        roundId = 1;

        vm.deal(user, TICKET_CAP * TICKET_COST);
        vm.prank(user);
        rips.buyTickets{value: TICKET_CAP * TICKET_COST}(stakeId, TICKET_CAP, user);

        vrfRequestId = rips.requestRandomness(roundId);
    }

    function test_WhenCalledByTheVRFCoordinator() external {
        uint256 randomWord = uint256(keccak256(abi.encode(vrfRequestId, uint256(0))));
        uint256 expectedA = RipsMath.deriveCoprimeA(randomWord, TICKET_CAP);
        uint256 expectedB = uint256(keccak256(abi.encode(randomWord))) % TICKET_CAP;

        vm.expectEmit(true, false, false, true);
        emit RoundFinalized(roundId, expectedA, expectedB);

        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));
    }
}
