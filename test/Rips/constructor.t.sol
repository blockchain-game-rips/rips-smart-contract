// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";

contract Rips_Constructor is RipsTestBase {
    function test_WhenDeployed() external view {
        assertTrue(rips.hasRole(rips.DEFAULT_ADMIN_ROLE(), owner));
        assertEq(rips.feeRecipient(), owner);
    }
}
