// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {RipsConduit} from "../src/RipsConduit.sol";

/// @dev Deploy the conduit bridges call instead of Rips directly.
///
/// The conduit reads the Rips address once at construction, so a Rips redeploy
/// needs a matching conduit redeploy.
///
/// Required env vars:
///   RIPS - Address of the deployed Rips contract
///
/// Usage:
///   forge script script/DeployConduit.s.sol --rpc-url $RPC_URL --broadcast --verify
contract DeployConduit is Script {
    function run() external returns (address conduit) {
        address rips = vm.envAddress("RIPS");

        vm.startBroadcast();

        conduit = address(new RipsConduit(rips));

        vm.stopBroadcast();

        console.log("conduit:", conduit);
    }
}
