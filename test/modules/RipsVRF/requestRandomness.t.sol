// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

contract Rips_RequestRandomness is RipsTestBase {
    event RandomnessRequested(uint256 indexed roundId, uint256 vrfRequestId);

    event RandomWordsRequested(
        bytes32 indexed keyHash,
        uint256 requestId,
        uint256 preSeed,
        uint256 indexed subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords,
        bytes extraArgs,
        address indexed sender
    );

    uint256 private constant TICKET_CAP = 2;
    uint256 private constant TICKET_COST = 1 ether;
    uint256 private constant EXPECTED_FIRST_REQUEST_ID = 1;

    uint256 private stakeId;
    uint256 private soldOutRoundId;

    function setUp() public override {
        super.setUp();

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

        soldOutRoundId = 1;

        vm.deal(user, TICKET_CAP * TICKET_COST);
        vm.prank(user);
        rips.buyTickets{value: TICKET_CAP * TICKET_COST}(stakeId, TICKET_CAP, user);
    }

    function test_RevertWhen_TheRoundIsNotSoldOut() external {
        uint256 activeRoundId = 2;

        vm.expectRevert(IRips.RoundNotSoldOut.selector);
        rips.requestRandomness(activeRoundId);
    }

    function test_WhenTheRoundIsSoldOut() external {
        vm.expectEmit(true, true, true, false, address(vrfCoordinator));
        emit RandomWordsRequested(
            VRF_KEY_HASH,
            0,
            0,
            vrfSubscriptionId,
            rips.VRF_REQUEST_CONFIRMATIONS(),
            VRF_CALLBACK_GAS_LIMIT,
            rips.VRF_NUM_WORDS(),
            "",
            address(rips)
        );

        uint256 requestId = rips.requestRandomness(soldOutRoundId);

        assertEq(requestId, EXPECTED_FIRST_REQUEST_ID);
    }
}
