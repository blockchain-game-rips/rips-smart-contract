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

    function calculatePrizeNumber(uint256 ticketNumber, uint256 a, uint256 b, uint256 n)
        internal
        pure
        returns (uint256)
    {
        return (a * ticketNumber + b) % n + 1;
    }

    function calculateTotalPrize(
        uint256 ticketNumber,
        uint256 a,
        uint256 b,
        uint256 n,
        IRips.PrizeTier[] memory prizeDistribution
    ) internal pure returns (uint256) {
        uint256 prizeNumber = calculatePrizeNumber(ticketNumber, a, b, n);

        return calculatePrizeAmount(prizeNumber, prizeDistribution);
    }

    function prizeForRankInTier(IRips.PrizeTier memory tier, uint256 rank)
        internal
        pure
        returns (uint256)
    {
        if (tier.prizeCount == 1) return tier.minPrize;

        uint256 prizeRange = tier.maxPrize - tier.minPrize;

        return tier.minPrize + (prizeRange * (rank - 1)) / (tier.prizeCount - 1);
    }

    function calculatePrizeAmount(uint256 prizeNumber, IRips.PrizeTier[] memory prizeDistribution)
        internal
        pure
        returns (uint256)
    {
        uint256 cumulativePrizes = 0;

        for (uint256 i = 0; i < prizeDistribution.length; i++) {
            IRips.PrizeTier memory tier = prizeDistribution[i];

            uint256 tierStart = cumulativePrizes + 1;
            uint256 tierEnd = cumulativePrizes + tier.prizeCount;

            if (prizeNumber >= tierStart && prizeNumber <= tierEnd) {
                return prizeForRankInTier(tier, prizeNumber - cumulativePrizes);
            }

            cumulativePrizes += tier.prizeCount;
        }

        // Unreachable: calculatePrizeNumber guarantees prizeNumber is in [1, totalPrizeCount].
        revert();
    }
}
