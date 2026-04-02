// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../interfaces/IRips.sol";

library RipsMath {
    function isPowerOfTwo(uint256 n) internal pure returns (bool) {
        return n > 0 && (n & (n - 1)) == 0;
    }

    function deriveCoprimeA(uint256 randomValue, uint256 n) internal pure returns (uint256) {
        uint256 a = randomValue % n;
        if (a == 0) a = 1;
        if (a % 2 == 0) a = a + 1;
        return a;
    }

    function calculateTicketPrize(
        uint256 ticketNumber,
        uint256 a,
        uint256 b,
        uint256 n,
        IRips.PrizeTier[] memory tiers,
        uint64[] memory tierBoundaries
    ) internal pure returns (uint256) {
        uint256 prizeNumber = (a * ticketNumber + b) % n + 1;

        for (uint256 t = 0; t < tierBoundaries.length; t++) {
            if (prizeNumber <= tierBoundaries[t]) {
                IRips.PrizeTier memory tier = tiers[t];
                uint256 rank = prizeNumber - (t == 0 ? 0 : tierBoundaries[t - 1]);

                if (tier.prizeCount == 1) return tier.minPrize;

                return tier.minPrize + ((tier.maxPrize - tier.minPrize) * (rank - 1))
                    / (tier.prizeCount - 1);
            }
        }

        //unreached
        revert();
    }
}
