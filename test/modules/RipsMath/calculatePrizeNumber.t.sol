// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract RipsMath_CalculatePrizeNumber is RipsTestBase {
    uint256 private constant HALF_UINT128 = type(uint128).max;

    function test_ResultIsAlwaysBetween1AndNInclusive(
        uint256 ticketNumber,
        uint256 a,
        uint256 b,
        uint256 n
    ) external view {
        vm.assume(n > 0);
        vm.assume(a <= HALF_UINT128 && ticketNumber <= HALF_UINT128 && b <= HALF_UINT128);

        uint256 result = rips.exposed_calculatePrizeNumber(ticketNumber, a, b, n);

        assertGe(result, 1);
        assertLe(result, n);
    }

    function test_DifferentTicketNumbersProduceDifferentPrizeNumbers(
        uint256 ticketA,
        uint256 ticketB,
        uint256 a,
        uint8 exponent
    ) external view {
        vm.assume(exponent > 0 && exponent < 128);

        uint256 n = 2 ** exponent;

        vm.assume(a <= HALF_UINT128 && ticketA <= HALF_UINT128 && ticketB <= HALF_UINT128);
        vm.assume(ticketA % n != ticketB % n);
        vm.assume(a % 2 != 0);

        uint256 b = 0;

        assertNotEq(
            rips.exposed_calculatePrizeNumber(ticketA, a, b, n),
            rips.exposed_calculatePrizeNumber(ticketB, a, b, n)
        );
    }

}
