// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract RipsMath_DeriveCoprimeA is RipsTestBase {
    function test_WhenTheRandomValueModNIsZero(uint256 randomValue, uint256 n) external view {
        vm.assume(n > 1);
        vm.assume(randomValue % n == 0);
        assertEq(rips.exposed_deriveCoprimeA(randomValue, n), 1);
    }

    function test_WhenTheRandomValueModNIsEven(uint256 randomValue, uint256 n) external view {
        vm.assume(n > 1);
        vm.assume(randomValue % n != 0 && randomValue % n % 2 == 0);
        assertEq(rips.exposed_deriveCoprimeA(randomValue, n) % 2, 1);
    }

    function test_WhenTheRandomValueModNIsOdd(uint256 randomValue, uint256 n) external view {
        vm.assume(n > 1);
        vm.assume(randomValue % n % 2 != 0);
        assertEq(rips.exposed_deriveCoprimeA(randomValue, n) % 2, 1);
    }
}
