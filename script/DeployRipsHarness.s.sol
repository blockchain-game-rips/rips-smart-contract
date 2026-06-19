// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {IRips} from "../src/interfaces/IRips.sol";
import {RipsHarness} from "../test/RipsHarness.sol";

uint256 constant VRF_FUND_AMOUNT = 10 ether;

contract DeployRips is Script {
    bytes32 private constant DEFAULT_KEY_HASH = bytes32(uint256(1));
    uint32 private constant DEFAULT_CALLBACK_GAS = 200_000;
    uint16 private constant DEFAULT_FEE_PERCENT = 500; // 5%
    uint16 private constant DEFAULT_REFERRAL_FEE = 2000; // 20%

    function run() external returns (address rips) {
        address coordinator = vm.envAddress("VRF_COORDINATOR");
        uint256 subscriptionId = vm.envUint("VRF_SUBSCRIPTION_ID");
        bytes32 keyHash = vm.envOr("VRF_KEY_HASH", DEFAULT_KEY_HASH);
        uint32 callbackGasLimit =
            uint32(vm.envOr("VRF_CALLBACK_GAS", uint256(DEFAULT_CALLBACK_GAS)));

        VRFCoordinatorV2_5Mock coordinatorContract = VRFCoordinatorV2_5Mock(coordinator);

        vm.startBroadcast();

        coordinatorContract.fundSubscription(subscriptionId, VRF_FUND_AMOUNT);

        RipsHarness ripsContract =
            new RipsHarness(coordinator, subscriptionId, keyHash, callbackGasLimit);

        ripsContract.setDefaultReferralFee(DEFAULT_REFERRAL_FEE);

        coordinatorContract.addConsumer(subscriptionId, address(ripsContract));

        _createDefaultPresets(ripsContract);

        vm.stopBroadcast();

        rips = address(ripsContract);

        console.log("rips:", rips);
    }

    function _createDefaultPresets(RipsHarness rips)
        internal
        returns (uint64 presetId1, uint64 presetId2)
    {
        presetId1 = _createDefaultPreset1(rips);
        presetId2 = _createDefaultPreset2(rips);
    }

    function _createDefaultPreset1(RipsHarness rips) internal returns (uint64 presetId) {
        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](3);

        tiers[0] =
            IRips.PayoutTier({payoutCount: 5, minPayout: 0.0008 ether, maxPayout: 0.0012 ether});

        tiers[1] =
            IRips.PayoutTier({payoutCount: 2, minPayout: 0.007 ether, maxPayout: 0.008 ether});

        tiers[2] =
            IRips.PayoutTier({payoutCount: 1, minPayout: 0.018 ether, maxPayout: 0.018 ether});

        presetId = rips.createPreset(
            IRips.Config({
                currency: address(0),
                tiers: tiers,
                entryCap: 8,
                duration: 5 minutes,
                entryPrice: 0.005 ether,
                feePercent: DEFAULT_FEE_PERCENT
            })
        );
    }

    function _createDefaultPreset2(RipsHarness rips) internal returns (uint64 presetId) {
        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](3);

        tiers[0] =
            IRips.PayoutTier({payoutCount: 5, minPayout: 0.0016 ether, maxPayout: 0.0024 ether});

        tiers[1] =
            IRips.PayoutTier({payoutCount: 2, minPayout: 0.014 ether, maxPayout: 0.016 ether});

        tiers[2] =
            IRips.PayoutTier({payoutCount: 1, minPayout: 0.036 ether, maxPayout: 0.036 ether});

        presetId = rips.createPreset(
            IRips.Config({
                currency: address(0),
                tiers: tiers,
                entryCap: 8,
                duration: 5 minutes,
                entryPrice: 0.01 ether,
                feePercent: DEFAULT_FEE_PERCENT
            })
        );
    }
}
