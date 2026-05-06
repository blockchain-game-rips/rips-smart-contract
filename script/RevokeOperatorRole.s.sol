// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {Rips} from "../src/Rips.sol";

/// Revoke OPERATOR_ROLE from an address on an already-deployed Rips contract.
///
/// Required env vars:
///   RIPS_ADDRESS   - Address of the deployed Rips contract
///   PRIVATE_KEY    - Private key of an account that holds DEFAULT_ADMIN_ROLE
///
/// Usage:
///   forge script script/RevokeOperatorRole.s.sol --sig "run(address)" <OPERATOR> --rpc-url $RPC_URL --broadcast
contract RevokeOperatorRole is Script {
    function run(address operator) external {
        address ripsAddress = vm.envAddress("RIPS_ADDRESS");

        Rips rips = Rips(ripsAddress);

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        rips.revokeRole(rips.OPERATOR_ROLE(), operator);

        vm.stopBroadcast();

        console.log("OPERATOR_ROLE revoked from:", operator);
    }
}
