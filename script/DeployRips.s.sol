// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import "../src/Rips.sol";
import {IRips} from "../src/interfaces/IRips.sol";

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

        Rips ripsContract = new Rips(coordinator, subscriptionId, keyHash, callbackGasLimit);

        ripsContract.setDefaultReferralFee(DEFAULT_REFERRAL_FEE);

        coordinatorContract.addConsumer(subscriptionId, address(ripsContract));

        _createDefaultStakes(ripsContract);

        vm.stopBroadcast();

        rips = address(ripsContract);

        console.log("rips:", rips);
    }

    function _createDefaultStakes(Rips rips) internal returns (uint64 stakeId1, uint64 stakeId2) {
        stakeId1 = _createDefaultStake1(rips);
        stakeId2 = _createDefaultStake2(rips);
    }

    function _createDefaultStake1(Rips rips) internal returns (uint64 stakeId) {
        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](3);

        tiers[0] = IRips.PrizeTier({prizeCount: 5, minPrize: 0.0008 ether, maxPrize: 0.0012 ether});

        tiers[1] = IRips.PrizeTier({prizeCount: 2, minPrize: 0.007 ether, maxPrize: 0.008 ether});

        tiers[2] = IRips.PrizeTier({prizeCount: 1, minPrize: 0.018 ether, maxPrize: 0.018 ether});

        stakeId = rips.createStake(
            IRips.Config({
                currency: address(0),
                tiers: tiers,
                ticketCap: 8,
                duration: 5 minutes,
                ticketCost: 0.005 ether,
                feePercent: DEFAULT_FEE_PERCENT
            })
        );
    }

    function _createDefaultStake2(Rips rips) internal returns (uint64 stakeId) {
        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](3);

        tiers[0] = IRips.PrizeTier({prizeCount: 5, minPrize: 0.0016 ether, maxPrize: 0.0024 ether});

        tiers[1] = IRips.PrizeTier({prizeCount: 2, minPrize: 0.014 ether, maxPrize: 0.016 ether});

        tiers[2] = IRips.PrizeTier({prizeCount: 1, minPrize: 0.036 ether, maxPrize: 0.036 ether});

        stakeId = rips.createStake(
            IRips.Config({
                currency: address(0),
                tiers: tiers,
                ticketCap: 8,
                duration: 5 minutes,
                ticketCost: 0.01 ether,
                feePercent: DEFAULT_FEE_PERCENT
            })
        );
    }
}
