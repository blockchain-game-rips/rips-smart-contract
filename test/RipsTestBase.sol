// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./RipsHarness.sol";
import "../script/VrfHelper.sol";
import "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RipsTestBase is Test {
    bytes32 internal constant VRF_KEY_HASH = bytes32(uint256(1));
    uint32 internal constant VRF_CALLBACK_GAS_LIMIT = 100_000;
    uint256 internal constant INITIAL_FEE_PERCENT = 500;

    uint256 internal constant DEFAULT_TICKET_CAP = 4;
    uint256 internal constant DEFAULT_TICKET_COST = 1 ether;
    uint256 internal constant DEFAULT_DURATION = 1 days;

    VRFCoordinatorV2_5Mock internal vrfCoordinator;
    RipsHarness internal rips;

    address internal owner = makeAddr("owner");
    address internal user = makeAddr("user");

    uint256 internal vrfSubscriptionId;

    function setUp() public virtual {
        (vrfCoordinator, vrfSubscriptionId) = VrfHelper.deployCoordinator();

        vm.prank(owner);
        rips = new RipsHarness(
            address(vrfCoordinator),
            vrfSubscriptionId,
            VRF_KEY_HASH,
            VRF_CALLBACK_GAS_LIMIT,
            INITIAL_FEE_PERCENT
        );

        vrfCoordinator.addConsumer(vrfSubscriptionId, address(rips));
    }

    function _createDefaultStake() internal returns (uint256 stakeId) {
        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: uint64(DEFAULT_TICKET_CAP),
            minPrize: uint128(DEFAULT_TICKET_COST),
            maxPrize: uint128(DEFAULT_TICKET_COST)
        });

        vm.prank(owner);
        stakeId = rips.createStake(
            IRips.StakeConfig({
                prizeDistribution: tiers,
                ticketCap: DEFAULT_TICKET_CAP,
                duration: DEFAULT_DURATION,
                ticketCost: DEFAULT_TICKET_COST
            })
        );
    }
}
