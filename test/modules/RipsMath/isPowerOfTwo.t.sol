// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract RipsMath_IsPowerOfTwo is RipsTestBase {
    function test_WhenNIsZero() external view {
        assertFalse(rips.exposed_isPowerOfTwo(0));
    }

    function test_WhenNIsAPowerOfTwo(uint8 exponent) external view {
        vm.assume(exponent < 128);
        assertTrue(rips.exposed_isPowerOfTwo(2 ** exponent));
    }

    function test_WhenNIsNotAPowerOfTwo(uint8 exponent) external view {
        vm.assume(exponent > 0 && exponent < 255);
        assertFalse(rips.exposed_isPowerOfTwo(2 ** exponent + 1));
    }
}
