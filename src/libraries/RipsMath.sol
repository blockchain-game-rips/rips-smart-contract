// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IRips} from "../interfaces/IRips.sol";

library RipsMath {
    function isPowerOfTwo(uint256 n) internal pure returns (bool) {
        return n > 0 && (n & (n - 1)) == 0;
    }

    function deriveCoprimeA(uint256 randomValue, uint64 n) internal pure returns (uint64) {
        // a <= n-1 < type(uint64).max, so a+1 cannot overflow
        // forge-lint: disable-next-line(unsafe-typecast)
        uint64 a = uint64(randomValue % n);

        if (a % 2 == 0) a = a + 1;

        return a;
    }

    function calculateEntryPayout(
        uint256 entryNumber,
        uint64 a,
        uint64 b,
        uint64 n,
        IRips.PayoutTier[] memory tiers,
        uint64[] memory tierBoundaries
    ) public pure returns (uint256) {
        uint256 payoutNumber = (uint256(a) * entryNumber + b) % n + 1;

        for (uint256 t = 0; t < tierBoundaries.length; t++) {
            if (payoutNumber <= tierBoundaries[t]) {
                IRips.PayoutTier memory tier = tiers[t];

                if (tier.payoutCount == 1) return tier.minPayout;

                uint256 rank = payoutNumber - (t == 0 ? 0 : tierBoundaries[t - 1]);

                return tier.minPayout + ((tier.maxPayout - tier.minPayout) * (rank - 1))
                    / (tier.payoutCount - 1);
            }
        }

        //unreachable
        revert();
    }
}
