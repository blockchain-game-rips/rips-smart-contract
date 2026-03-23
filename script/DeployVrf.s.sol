// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

uint96 constant VRF_BASE_FEE = 0.001 ether;
uint96 constant VRF_GAS_PRICE = 0;
int256 constant VRF_WEI_PER_UNIT_LINK = 1e18;

contract DeployVrf is Script {
    function run() external returns (address coordinator) {
        vm.startBroadcast();

        VRFCoordinatorV2_5Mock coordinatorContract =
            new VRFCoordinatorV2_5Mock(VRF_BASE_FEE, VRF_GAS_PRICE, VRF_WEI_PER_UNIT_LINK);

        coordinatorContract.createSubscription();

        vm.stopBroadcast();

        coordinator = address(coordinatorContract);

        console.log("coordinator:", coordinator);
    }
}
