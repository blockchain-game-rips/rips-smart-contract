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

    uint64 private constant TICKET_CAP = 2;
    uint256 private constant TICKET_COST = 1 ether;
    uint256 private constant EXPECTED_FIRST_REQUEST_ID = 1;

    uint256 private stakeId;
    uint256 private soldOutRoundId;
    uint256 private activeRoundId;

    function setUp() public override {
        super.setUp();

        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: uint64(TICKET_CAP),
            minPrize: uint128(TICKET_COST),
            maxPrize: uint128(TICKET_COST)
        });

        vm.startPrank(owner);
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
        vm.stopPrank();

        vm.deal(user, TICKET_CAP * TICKET_COST);
        vm.prank(user);
        rips.buyTickets{value: TICKET_CAP * TICKET_COST}(stakeId, TICKET_CAP, user);

        soldOutRoundId = rips.stakeIdToCurrentRoundId(stakeId);

        // create a second stake and buy one ticket to initialize the round (but not sell out)
        vm.prank(owner);
        uint256 stakeId2 = rips.createStake(
            IRips.Config({
                currency: address(0),
                tiers: tiers,
                ticketCap: TICKET_CAP,
                duration: 1 days,
                ticketCost: TICKET_COST,
                feePercent: 0
            })
        );
        vm.deal(user, TICKET_COST);
        vm.prank(user);
        rips.buyTickets{value: TICKET_COST}(stakeId2, 1, user);
        activeRoundId = rips.stakeIdToCurrentRoundId(stakeId2);
    }

    function test_RevertWhen_TheRoundDoesNotExist() external {
        uint256 nonExistentRoundId = 999;
        vm.expectRevert(IRips.RoundNotExist.selector);
        rips.requestRandomness(nonExistentRoundId);
    }

    function test_RevertWhen_TheVrfRequestStatusIsNotNotRequested() external {
        // request once to move status to Requested
        vrfCoordinator.fundSubscription(vrfSubscriptionId, 100 ether);
        rips.requestRandomness(soldOutRoundId);

        vm.expectRevert(IRips.VrfAlreadyRequested.selector);
        rips.requestRandomness(soldOutRoundId);
    }

    function test_RevertWhen_TheRoundIsNotSoldOut() external {
        vm.expectRevert(IRips.RoundNotSoldOut.selector);
        rips.requestRandomness(activeRoundId);
    }

    modifier whenTheRoundExistsIsActiveAndIsSoldOut() {
        vrfCoordinator.fundSubscription(vrfSubscriptionId, 100 ether);
        _;
    }

    function test_WhenTheRoundExistsIsActiveAndIsSoldOut()
        external
        whenTheRoundExistsIsActiveAndIsSoldOut
    {
        vm.expectEmit(true, true, true, false, address(vrfCoordinator));
        emit RandomWordsRequested(
            VRF_KEY_HASH,
            0,
            0,
            vrfSubscriptionId,
            rips.vrfRequestConfirmations(),
            VRF_CALLBACK_GAS_LIMIT,
            rips.VRF_NUM_WORDS(),
            "",
            address(rips)
        );

        vm.expectEmit();
        emit RandomnessRequested(soldOutRoundId, EXPECTED_FIRST_REQUEST_ID);

        uint256 requestId = rips.requestRandomness(soldOutRoundId);

        assertEq(requestId, EXPECTED_FIRST_REQUEST_ID);

        IRips.Round memory round = rips.exposed_round(soldOutRoundId);
        assertEq(uint8(round.vrfRequestStatus), uint8(IRips.VrfRequestStatus.Requested));

        assertEq(rips.exposed_requestTimestamp(soldOutRoundId), block.timestamp);
    }
}
