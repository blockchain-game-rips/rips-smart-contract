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

    function exposed_rip(uint256 ripId) external view returns (Rip memory) {
        return ripIdToRip[ripId];
    }

    function exposed_config(uint64 configId) external view returns (Config memory) {
        return configIdToConfig[configId];
    }

    function exposed_referrerStats(address referrer, address currency)
        external
        view
        returns (ReferrerState memory)
    {
        return referrerToReferrerState[referrer][currency];
    }

    function exposed_collectReferrerFee(
        address referrer,
        address currency,
        uint256 protocolFee,
        uint256 entryRevenue
    ) external returns (uint256) {
        return _collectReferrerFee(referrer, currency, protocolFee, entryRevenue);
    }

    function exposed_requestTimestamp(uint256 ripId) external view returns (uint256) {
        return _ripIdToRequestTimestamp[ripId];
    }

    function exposed_nextStakeId() external view returns (uint64) {
        return _nextStakeId;
    }

    function exposed_nextRipId() external view returns (uint256) {
        return _nextRipId;
    }

    function exposed_nextConfigId() external view returns (uint64) {
        return _nextConfigId;
    }

    function exposed_calculateEntryPayout(
        uint256 entryNumber,
        uint64 a,
        uint64 b,
        uint64 n,
        IRips.PayoutTier[] memory tiers,
        uint64[] memory tierBoundaries
    ) external pure returns (uint256) {
        return RipsMath.calculateEntryPayout(entryNumber, a, b, n, tiers, tierBoundaries);
    }
}
