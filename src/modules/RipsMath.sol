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
        return (a * ticketNumber + b) % n;
    }

    function calculateTotalPrize(
        uint256 ticketNumber,
        uint256 a,
        uint256 b,
        uint256 n,
        IRips.StakeConfig storage config
    ) internal view returns (uint256) {
        uint256 prizeNumber = calculatePrizeNumber(ticketNumber, a, b, n);

        return calculatePrizeAmount(prizeNumber, config);
    }

    function prizeForPositionInTier(IRips.PrizeTier storage tier, uint256 positionInTier)
        internal
        view
        returns (uint256)
    {
        if (tier.winnersInTier == 1) return tier.minPrize;

        uint256 prizeRange = tier.maxPrize - tier.minPrize;

        return tier.minPrize + (prizeRange * positionInTier) / (tier.winnersInTier - 1);
    }

    function calculatePrizeAmount(uint256 prizeNumber, IRips.StakeConfig storage config)
        internal
        view
        returns (uint256)
    {
        uint256 cumulativeWinners = 0;

        for (uint256 i = 0; i < config.prizeDistribution.length; i++) {
            IRips.PrizeTier storage tier = config.prizeDistribution[i];

            uint256 tierStart = cumulativeWinners + 1;
            uint256 tierEnd = cumulativeWinners + tier.winnersInTier;

            if (prizeNumber >= tierStart && prizeNumber <= tierEnd) {
                return prizeForPositionInTier(tier, prizeNumber - tierStart);
            }

            cumulativeWinners += tier.winnersInTier;
        }

        // Unreachable: calculatePrizeNumber guarantees prizeNumber is in [1, totalWinners].
        revert();
    }
}
