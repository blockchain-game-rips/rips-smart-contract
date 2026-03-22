// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Rips.sol";

/// @dev Deploy to production with a real Chainlink VRF coordinator.
///
/// Required env vars:
///   VRF_COORDINATOR      - Chainlink VRF coordinator address for the target network
///   VRF_SUBSCRIPTION_ID  - Funded VRF subscription ID
///   VRF_KEY_HASH         - Key hash (gas lane) for the target network
///   VRF_CALLBACK_GAS     - Gas limit for the VRF fulfillRandomWords callback
///   INITIAL_FEE_PERCENT  - Protocol fee in basis points (e.g. 500 = 5%)
///
/// The deployer (--sender) becomes the owner and initial fee recipient.
///
/// Usage:
///   forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --verify
contract Deploy is Script {
    function run() external returns (address rips) {
        address vrfCoordinator = vm.envAddress("VRF_COORDINATOR");
        uint256 subscriptionId = vm.envUint("VRF_SUBSCRIPTION_ID");
        bytes32 keyHash = vm.envBytes32("VRF_KEY_HASH");
        uint32 callbackGasLimit = uint32(vm.envUint("VRF_CALLBACK_GAS"));
        uint256 feePercent = vm.envUint("INITIAL_FEE_PERCENT");

        vm.startBroadcast();
        rips = address(
            new Rips(vrfCoordinator, subscriptionId, keyHash, callbackGasLimit, feePercent)
        );
        vm.stopBroadcast();
    }
}
