// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract RipsMath_DeriveCoprimeA is RipsTestBase {
    function test_WhenTheRandomValueModNIsZero(uint256 randomValue, uint64 n) external view {
        vm.assume(n > 1);
        vm.assume(randomValue % n == 0);
        assertEq(rips.exposed_deriveCoprimeA(randomValue, n), 1);
    }

    function test_WhenTheRandomValueModNIsEven(uint256 randomValue, uint64 n) external view {
        vm.assume(n > 1);
        vm.assume(randomValue % n != 0 && randomValue % n % 2 == 0);
        assertEq(rips.exposed_deriveCoprimeA(randomValue, n) % 2, 1);
    }

    function test_WhenTheRandomValueModNIsOdd(uint256 randomValue, uint64 n) external view {
        vm.assume(n > 1);
        vm.assume(randomValue % n % 2 != 0);
        assertEq(rips.exposed_deriveCoprimeA(randomValue, n) % 2, 1);
    }

    function test_WhenTheRandomValueIsZero(uint64 n) external view {
        vm.assume(n > 1);
        assertEq(rips.exposed_deriveCoprimeA(0, n), 1);
    }

    function test_WhenTheRandomValueIsTypeUint256Max(uint64 n) external view {
        vm.assume(n > 1);
        assertEq(rips.exposed_deriveCoprimeA(type(uint256).max, n) % 2, 1);
    }

    function test_WhenTheRandomValueIsTypeUint256MaxMinusOne(uint64 n) external view {
        vm.assume(n > 1);
        assertEq(rips.exposed_deriveCoprimeA(type(uint256).max - 1, n) % 2, 1);
    }
}
