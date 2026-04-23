// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Rips} from "../src/Rips.sol";

/// Grant OPERATOR_ROLE to an address on an already-deployed Rips contract.
///
/// Required env vars:
///   RIPS_ADDRESS   - Address of the deployed Rips contract
///   OPERATOR       - Address to grant the operator role to
///   PRIVATE_KEY    - Private key of an account that holds DEFAULT_ADMIN_ROLE
///
/// Usage:
///   forge script script/GrantOperatorRole.s.sol --rpc-url $RPC_URL --broadcast
contract GrantOperatorRole is Script {
    function run() external {
        address ripsAddress = vm.envAddress("RIPS_ADDRESS");
        address operator = vm.envAddress("OPERATOR");

        Rips rips = Rips(ripsAddress);

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        rips.grantRole(rips.OPERATOR_ROLE(), operator);

        vm.stopBroadcast();

        console.log("OPERATOR_ROLE granted to:", operator);
    }
}
