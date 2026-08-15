// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/Rips.sol";
import {IRips} from "../src/interfaces/IRips.sol";
import {RipsConduit} from "../src/RipsConduit.sol";

/// @dev Deploy Rips and its conduit to production with a real Chainlink VRF coordinator.
///
/// Required env vars:
///   VRF_COORDINATOR      - Chainlink VRF coordinator address for the target network
///   VRF_SUBSCRIPTION_ID  - Funded VRF subscription ID
///   VRF_KEY_HASH         - Key hash (gas lane) for the target network
///   PRIVATE_KEY          - Deployer key used to broadcast the deployment
///
/// The deployer (PRIVATE_KEY) becomes the owner and initial fee recipient.
///
/// Usage:
///   forge script script/Deploy.s.sol --rpc-url $RPC_URL --broadcast --verify
contract Deploy is Script {
    uint256 private constant MID_ENTRY_PRICE = 0.00005 ether;

    function run() external returns (address rips, address conduit) {
        uint32 defaultCallbackGas = 300_000;
        uint16 defaultReferralFee = 2000; // 20%

        address vrfCoordinator = vm.envAddress("VRF_COORDINATOR");
        uint256 subscriptionId = vm.envUint("VRF_SUBSCRIPTION_ID");
        bytes32 keyHash = vm.envBytes32("VRF_KEY_HASH");
        uint32 callbackGasLimit = defaultCallbackGas;

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        Rips ripsContract = new Rips(vrfCoordinator, subscriptionId, keyHash, callbackGasLimit);

        rips = address(ripsContract);

        ripsContract.setDefaultReferralFee(defaultReferralFee);

        _createDefaultPresets(ripsContract);
        _createDefaultReferralTiers(ripsContract);

        conduit = address(new RipsConduit(rips));

        vm.stopBroadcast();

        console.log("rips:", rips);
        console.log("conduit:", conduit);
    }

    /// @dev Volume thresholds are expressed as entry counts at the middle preset price.
    function _createDefaultReferralTiers(Rips rips) internal {
        uint256 tier1Entries = 10;
        uint256 tier2Entries = 20;
        uint256 tier3Entries = 30;

        uint16 tier1Fee = 3000; // 30%
        uint16 tier2Fee = 4000; // 40%
        uint16 tier3Fee = 5000; // 50%

        IRips.ReferralTier[] memory tiers = new IRips.ReferralTier[](3);

        tiers[0] =
            IRips.ReferralTier({minVolume: uint128(tier1Entries * MID_ENTRY_PRICE), feeBps: tier1Fee});

        tiers[1] =
            IRips.ReferralTier({minVolume: uint128(tier2Entries * MID_ENTRY_PRICE), feeBps: tier2Fee});

        tiers[2] =
            IRips.ReferralTier({minVolume: uint128(tier3Entries * MID_ENTRY_PRICE), feeBps: tier3Fee});

        rips.setReferralTiers(address(0), tiers);
    }

    function _createDefaultPresets(Rips rips)
        internal
        returns (uint64 presetId1, uint64 presetId2, uint64 presetId3)
    {
        uint256 lowEntryPrice = 0.000025 ether;
        uint256 highEntryPrice = 0.0001 ether;

        presetId1 = _createDefaultPreset(rips, lowEntryPrice);
        presetId2 = _createDefaultPreset(rips, MID_ENTRY_PRICE);
        presetId3 = _createDefaultPreset(rips, highEntryPrice);
    }

    function _createDefaultPreset(Rips rips, uint256 entryPrice)
        internal
        returns (uint64 presetId)
    {
        uint64 defaultEntryCap = 8;
        uint32 defaultDuration = 5 minutes;
        uint16 defaultFeePercent = 500; // 5%

        presetId = rips.createPreset(
            IRips.Config({
                currency: address(0),
                tiers: _defaultTiers(entryPrice),
                entryCap: defaultEntryCap,
                duration: defaultDuration,
                entryPrice: entryPrice,
                feeBps: defaultFeePercent
            })
        );
    }

    /// @dev Payout percentages must total 760% of the entry price so the pool
    /// matches entryCap * entryPrice minus the 5% protocol fee.
    function _defaultTiers(uint256 entryPrice)
        internal
        pure
        returns (IRips.PayoutTier[] memory tiers)
    {
        uint256 tierCount = 7;

        tiers = new IRips.PayoutTier[](tierCount);

        tiers[0] = _tier(2, entryPrice, 10, 20);
        tiers[1] = _tier(1, entryPrice, 50, 50);
        tiers[2] = _tier(1, entryPrice, 80, 80);
        tiers[3] = _tier(1, entryPrice, 120, 120);
        tiers[4] = _tier(1, entryPrice, 140, 140);
        tiers[5] = _tier(1, entryPrice, 160, 160);
        tiers[6] = _tier(1, entryPrice, 180, 180);
    }

    function _tier(uint64 payoutCount, uint256 entryPrice, uint256 minPercent, uint256 maxPercent)
        internal
        pure
        returns (IRips.PayoutTier memory)
    {
        uint256 percentDenominator = 100;

        return IRips.PayoutTier({
            payoutCount: payoutCount,
            minPayout: uint128(entryPrice * minPercent / percentDenominator),
            maxPayout: uint128(entryPrice * maxPercent / percentDenominator)
        });
    }
}
