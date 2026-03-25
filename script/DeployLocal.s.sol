// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Rips.sol";
import "./VrfSetup.sol";

contract DeployLocal is Script {
    bytes32 private constant DEFAULT_KEY_HASH = bytes32(uint256(1));
    uint32 private constant DEFAULT_CALLBACK_GAS = 100_000;
    uint256 private constant DEFAULT_FEE_PERCENT = 500; // 5%

    function run() external returns (address rips, address vrfSetup) {
        bytes32 keyHash = vm.envOr("VRF_KEY_HASH", DEFAULT_KEY_HASH);
        uint32 callbackGasLimit =
            uint32(vm.envOr("VRF_CALLBACK_GAS", uint256(DEFAULT_CALLBACK_GAS)));
        uint256 feePercent = vm.envOr("INITIAL_FEE_PERCENT", DEFAULT_FEE_PERCENT);

        vm.startBroadcast();

        VrfSetup vrfSetupContract = new VrfSetup();
        VRFCoordinatorV2_5Mock coordinatorContract = vrfSetupContract.coordinator();
        uint256 subscriptionId = vrfSetupContract.subscriptionId();

        Rips ripsContract = new Rips(
            address(coordinatorContract), subscriptionId, keyHash, callbackGasLimit, feePercent
        );

        vrfSetupContract.addConsumer(address(ripsContract));

        _createDefaultStakes(ripsContract);

        vm.stopBroadcast();

        rips = address(ripsContract);
        vrfSetup = address(vrfSetupContract);
    }

    function _createDefaultStakes(Rips rips) internal {
        _createDefaultStake1(rips);
        _createDefaultStake2(rips);
    }

    function _createDefaultStake1(Rips rips) internal returns (uint256 stakeId) {
        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](3);

        tiers[0] = IRips.PrizeTier({prizeCount: 5, minPrize: 0.0008 ether, maxPrize: 0.0012 ether});

        tiers[1] = IRips.PrizeTier({prizeCount: 2, minPrize: 0.007 ether, maxPrize: 0.008 ether});

        tiers[2] = IRips.PrizeTier({prizeCount: 1, minPrize: 0.02 ether, maxPrize: 0.02 ether});

        stakeId = rips.createStake(
            IRips.StakeConfig({
                prizeDistribution: tiers, ticketCap: 8, duration: 5 minutes, ticketCost: 0.005 ether
            })
        );
    }

    function _createDefaultStake2(Rips rips) internal returns (uint256 stakeId) {
        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](3);

        tiers[0] = IRips.PrizeTier({prizeCount: 5, minPrize: 0.0016 ether, maxPrize: 0.0024 ether});

        tiers[1] = IRips.PrizeTier({prizeCount: 2, minPrize: 0.014 ether, maxPrize: 0.016 ether});

        tiers[2] = IRips.PrizeTier({prizeCount: 1, minPrize: 0.04 ether, maxPrize: 0.04 ether});

        stakeId = rips.createStake(
            IRips.StakeConfig({
                prizeDistribution: tiers, ticketCap: 8, duration: 5 minutes, ticketCost: 0.01 ether
            })
        );
    }
}
