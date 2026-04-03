// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../src/Rips.sol";
import "../src/libraries/RipsMath.sol";

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

    function exposed_deriveCoprimeA(uint256 randomValue, uint64 n) external pure returns (uint64) {
        return RipsMath.deriveCoprimeA(randomValue, n);
    }

    function exposed_round(uint256 roundId) external view returns (Round memory) {
        return roundIdToRound[roundId];
    }

    function exposed_config(uint256 configId) external view returns (Config memory) {
        return configIdToConfig[configId];
    }

    function exposed_referrerStats(address referrer) external view returns (ReferrerStats memory) {
        return referrerToReferrerStats[referrer];
    }

    function exposed_nextStakeId() external view returns (uint256) {
        return _nextStakeId;
    }

    function exposed_nextRoundId() external view returns (uint256) {
        return _nextRoundId;
    }

    function exposed_calculateTicketPrize(
        uint256 ticketNumber,
        uint64 a,
        uint64 b,
        uint64 n,
        IRips.PrizeTier[] memory tiers,
        uint64[] memory tierBoundaries
    ) external pure returns (uint256) {
        return RipsMath.calculateTicketPrize(ticketNumber, a, b, n, tiers, tierBoundaries);
    }
}
