// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./RipsHarness.sol";
import "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RipsTestBase is Test {
    bytes32 internal constant VRF_KEY_HASH = bytes32(uint256(1));
    uint32 internal constant VRF_CALLBACK_GAS_LIMIT = 100_000;
    uint256 internal constant INITIAL_FEE_PERCENT = 500;

    VRFCoordinatorV2_5Mock internal vrfCoordinator;
    RipsHarness internal rips;

    address internal owner = makeAddr("owner");
    address internal user = makeAddr("user");

    uint256 internal vrfSubscriptionId;

    function setUp() public virtual {
        vrfCoordinator = _deployVrfCoordinator();

        rips = new RipsHarness(
            address(vrfCoordinator),
            vrfSubscriptionId,
            VRF_KEY_HASH,
            VRF_CALLBACK_GAS_LIMIT,
            owner,
            INITIAL_FEE_PERCENT
        );

        vrfCoordinator.addConsumer(vrfSubscriptionId, address(rips));
    }

    uint96 private constant VRF_BASE_FEE = 0.1 ether;
    uint96 private constant VRF_GAS_PRICE = 1 gwei;
    int256 private constant VRF_WEI_PER_UNIT_LINK = 4e15;
    uint256 private constant VRF_FUND_AMOUNT = 10 ether;

    function _deployVrfCoordinator() private returns (VRFCoordinatorV2_5Mock coordinator) {
        coordinator = new VRFCoordinatorV2_5Mock(VRF_BASE_FEE, VRF_GAS_PRICE, VRF_WEI_PER_UNIT_LINK);
        vrfSubscriptionId = coordinator.createSubscription();
        coordinator.fundSubscription(vrfSubscriptionId, VRF_FUND_AMOUNT);
    }
}
