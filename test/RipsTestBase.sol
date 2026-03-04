// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./RipsHarness.sol";
import "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RipsTestBase is Test {
    VRFCoordinatorV2_5Mock internal vrfCoordinator;
    RipsHarness internal rips;

    address internal owner = makeAddr("owner");
    address internal user = makeAddr("user");

    uint256 internal subscriptionId;

    function setUp() public virtual {
        vrfCoordinator = new VRFCoordinatorV2_5Mock(0.1 ether, 1 gwei, 4e15);

        subscriptionId = vrfCoordinator.createSubscription();
        vrfCoordinator.fundSubscription(subscriptionId, 10 ether);

        vm.prank(owner);
        rips = new RipsHarness(
            address(vrfCoordinator),
            subscriptionId,
            bytes32(uint256(1)),
            100_000,
            owner,
            500
        );

        vrfCoordinator.addConsumer(subscriptionId, address(rips));
    }
}
