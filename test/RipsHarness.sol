// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../src/Rips.sol";
import "../src/modules/RipsMath.sol";

contract RipsHarness is Rips {
    constructor(
        address vrfCoordinator,
        uint256 vrfSubscriptionId,
        bytes32 vrfKeyHash,
        uint32 callbackGasLimit
    ) Rips(vrfCoordinator, vrfSubscriptionId, vrfKeyHash, callbackGasLimit) {}

    function exposed_isPowerOfTwo(uint256 n) external pure returns (bool) {
        return RipsMath.isPowerOfTwo(n);
    }

    function exposed_deriveCoprimeA(uint256 randomValue, uint256 n)
        external
        pure
        returns (uint256)
    {
        return RipsMath.deriveCoprimeA(randomValue, n);
    }

    function exposed_calculatePrizeNumber(uint256 ticketNumber, uint256 a, uint256 b, uint256 n)
        external
        pure
        returns (uint256)
    {
        return RipsMath.calculatePrizeNumber(ticketNumber, a, b, n);
    }

    function exposed_prizeForRankInTier(uint256 stakeId, uint256 tierIndex, uint256 rank)
        external
        view
        returns (uint256)
    {
        PrizeTier memory tier = configIdToConfig[stakeId].prizeDistribution[tierIndex];

        return RipsMath.prizeForRankInTier(tier, rank);
    }

    function exposed_calculatePrizeAmount(uint256 prizeNumber, uint256 stakeId)
        external
        view
        returns (uint256)
    {
        PrizeTier[] memory prizeDistribution = configIdToConfig[stakeId].prizeDistribution;
        uint64[] memory tierBoundaries = configIdToTierBoundaries[stakeId];

        return RipsMath.calculatePrizeAmount(prizeNumber, prizeDistribution, tierBoundaries);
    }

    function exposed_calculateTotalPrize(
        uint256 ticketNumber,
        uint256 a,
        uint256 b,
        uint256 n,
        uint256 stakeId
    ) external view returns (uint256) {
        PrizeTier[] memory prizeDistribution = configIdToConfig[stakeId].prizeDistribution;
        uint64[] memory tierBoundaries = configIdToTierBoundaries[stakeId];

        return
            RipsMath.calculateTotalPrize(ticketNumber, a, b, n, prizeDistribution, tierBoundaries);
    }

    function exposed_nextStakeId() external view returns (uint256) {
        return _nextStakeId;
    }

    function exposed_nextRoundId() external view returns (uint256) {
        return _nextRoundId;
    }

    function exposed_config(uint256 configId) external view returns (Config memory) {
        return configIdToConfig[configId];
    }

    function exposedstakeIdToCurrentRoundId(uint256 stakeId) external view returns (uint256) {
        return stakeIdToCurrentRoundId[stakeId];
    }

    function exposed_round(uint256 roundId) external view returns (Round memory) {
        return roundIdToRound[roundId];
    }

    function exposedisStakeDeleted(uint256 stakeId) external view returns (bool) {
        return isStakeDeleted[stakeId];
    }

    function exposed_hasRefunded(uint256 roundId, address user) external view returns (bool) {
        return _hasRefunded[roundId][user];
    }

    function exposedstakeIdToCurrentConfigId(uint256 stakeId) external view returns (uint256) {
        return _activeStakeConfigId[stakeId];
    }

    function exposedreferrerToReferrerStats(address referrer)
        external
        view
        returns (ReferrerStats memory)
    {
        return referrerToReferrerStats[referrer];
    }
}
