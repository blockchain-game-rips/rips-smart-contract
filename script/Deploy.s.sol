// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Rips.sol";
import {IRips} from "../src/interfaces/IRips.sol";

/// @dev Deploy to production with a real Chainlink VRF coordinator.
///
/// Required env vars:
///   VRF_COORDINATOR      - Chainlink VRF coordinator address for the target network
///   VRF_SUBSCRIPTION_ID  - Funded VRF subscription ID
///   VRF_KEY_HASH         - Key hash (gas lane) for the target network
///   VRF_CALLBACK_GAS     - Gas limit for the VRF fulfillRandomWords callback
///
/// The deployer (--sender) becomes the owner and initial fee recipient.
///
/// Usage:
///   forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --verify
contract Deploy is Script {
    uint32 private constant DEFAULT_CALLBACK_GAS = 300_000;
    uint16 private constant DEFAULT_FEE_PERCENT = 500; // 5%

    function run() external returns (address rips) {
        address vrfCoordinator = vm.envAddress("VRF_COORDINATOR");
        uint256 subscriptionId = vm.envUint("VRF_SUBSCRIPTION_ID");
        bytes32 keyHash = vm.envBytes32("VRF_KEY_HASH");
        uint32 callbackGasLimit = uint32(DEFAULT_CALLBACK_GAS);

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        Rips ripsContract = new Rips(vrfCoordinator, subscriptionId, keyHash, callbackGasLimit);

        rips = address(ripsContract);
        _createDefaultStakes(ripsContract);

        vm.stopBroadcast();
    }

    function _createDefaultStakes(Rips rips) internal returns (uint64 stakeId1, uint64 stakeId2) {
        stakeId1 = _createDefaultStake1(rips);
        stakeId2 = _createDefaultStake2(rips);
    }

    function _createDefaultStake1(Rips rips) internal returns (uint64 stakeId) {
        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](3);

        tiers[0] =
            IRips.PayoutTier({payoutCount: 5, minPayout: 0.00008 ether, maxPayout: 0.00012 ether});

        tiers[1] =
            IRips.PayoutTier({payoutCount: 2, minPayout: 0.0007 ether, maxPayout: 0.0008 ether});

        tiers[2] =
            IRips.PayoutTier({payoutCount: 1, minPayout: 0.0018 ether, maxPayout: 0.0018 ether});

        stakeId = rips.createStake(
            IRips.Config({
                currency: address(0),
                tiers: tiers,
                entryCap: 8,
                duration: 5 minutes,
                entryPrice: 0.0005 ether,
                feePercent: DEFAULT_FEE_PERCENT
            })
        );
    }

    function _createDefaultStake2(Rips rips) internal returns (uint64 stakeId) {
        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](3);

        tiers[0] =
            IRips.PayoutTier({payoutCount: 5, minPayout: 0.00016 ether, maxPayout: 0.00024 ether});

        tiers[1] =
            IRips.PayoutTier({payoutCount: 2, minPayout: 0.0014 ether, maxPayout: 0.0016 ether});

        tiers[2] =
            IRips.PayoutTier({payoutCount: 1, minPayout: 0.0036 ether, maxPayout: 0.0036 ether});

        stakeId = rips.createStake(
            IRips.Config({
                currency: address(0),
                tiers: tiers,
                entryCap: 8,
                duration: 5 minutes,
                entryPrice: 0.001 ether,
                feePercent: DEFAULT_FEE_PERCENT
            })
        );
    }
}
