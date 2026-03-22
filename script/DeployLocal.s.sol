// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Rips.sol";
import "./VrfHelper.sol";
import "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

/// @dev Deploy to a local Anvil node. Deploys a VRF coordinator mock and registers
///      Rips as a consumer automatically — no external Chainlink setup required.
///
/// Optional env vars (fall back to defaults when not set):
///   VRF_KEY_HASH         - Key hash (default: bytes32(uint256(1)))
///   VRF_CALLBACK_GAS     - Gas limit for the VRF callback (default: 100_000)
///   INITIAL_FEE_PERCENT  - Protocol fee in basis points (default: 500)
///
/// The deployer (--sender or first Anvil account) becomes the owner and initial fee recipient.
///
/// Usage:
///   anvil
///   forge script script/DeployLocal.s.sol --rpc-url http://localhost:8545 --broadcast
contract DeployLocal is Script {
    bytes32 private constant DEFAULT_KEY_HASH = bytes32(uint256(1));
    uint32 private constant DEFAULT_CALLBACK_GAS = 100_000;
    uint256 private constant DEFAULT_FEE_PERCENT = 500;

    function run() external returns (address coordinator, address rips) {
        bytes32 keyHash = vm.envOr("VRF_KEY_HASH", DEFAULT_KEY_HASH);
        uint32 callbackGasLimit =
            uint32(vm.envOr("VRF_CALLBACK_GAS", uint256(DEFAULT_CALLBACK_GAS)));
        uint256 feePercent = vm.envOr("INITIAL_FEE_PERCENT", DEFAULT_FEE_PERCENT);

        // blockhash(block.number - 1) is used in createSubscription; Anvil starts at block 0
        // so we advance one block to avoid an underflow revert.
        vm.roll(block.number + 1);

        vm.startBroadcast();

        (VRFCoordinatorV2_5Mock vrfCoordinator, uint256 subscriptionId) =
            VrfHelper.deployCoordinator();

        Rips ripsContract = new Rips(
            address(vrfCoordinator), subscriptionId, keyHash, callbackGasLimit, feePercent
        );

        vrfCoordinator.addConsumer(subscriptionId, address(ripsContract));

        vm.stopBroadcast();

        coordinator = address(vrfCoordinator);
        rips = address(ripsContract);
    }
}
