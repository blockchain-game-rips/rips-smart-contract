// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Rips.sol";
import "./VrfSetup.sol";

contract DeployLocal is Script {
    bytes32 private constant DEFAULT_KEY_HASH = bytes32(uint256(1));
    uint32 private constant DEFAULT_CALLBACK_GAS = 100_000;
    uint256 private constant DEFAULT_FEE_PERCENT = 500; // 5%

    function run() external returns (address rips, uint256 stakeId) {
        bytes32 keyHash = vm.envOr("VRF_KEY_HASH", DEFAULT_KEY_HASH);
        uint32 callbackGasLimit =
            uint32(vm.envOr("VRF_CALLBACK_GAS", uint256(DEFAULT_CALLBACK_GAS)));
        uint256 feePercent = vm.envOr("INITIAL_FEE_PERCENT", DEFAULT_FEE_PERCENT);

        vm.startBroadcast();

        VrfSetup vrfSetup = new VrfSetup();
        VRFCoordinatorV2_5Mock coordinator = vrfSetup.coordinator();
        uint256 subscriptionId = vrfSetup.subscriptionId();

        Rips ripsContract =
            new Rips(address(coordinator), subscriptionId, keyHash, callbackGasLimit, feePercent);

        vrfSetup.addConsumer(address(ripsContract));

        stakeId = _createDefaultStake(ripsContract);

        vm.stopBroadcast();

        rips = address(ripsContract);
    }

    function _createDefaultStake(Rips rips) internal returns (uint256 stakeId) {
        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](3);

        tiers[0] = IRips.PrizeTier({prizeCount: 5, minPrize: 0.0008 ether, maxPrize: 0.0012 ether});

        tiers[1] = IRips.PrizeTier({prizeCount: 2, minPrize: 0.007 ether, maxPrize: 0.008 ether});

        tiers[2] = IRips.PrizeTier({prizeCount: 1, minPrize: 0.02 ether, maxPrize: 0.02 ether});

        stakeId = rips.createStake(
            IRips.StakeConfig({
                prizeDistribution: tiers, ticketCap: 8, duration: 1 days, ticketCost: 0.005 ether
            })
        );
    }
}
