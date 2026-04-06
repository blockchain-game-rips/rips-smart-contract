// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RipsStorage} from "../common/RipsStorage.sol";
import {RipsMath} from "../libraries/RipsMath.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {RipsUtils} from "../common/RipsUtils.sol";

abstract contract RipsAdmin is RipsStorage, RipsUtils, Pausable {
    uint256 public constant MAX_TIER_COUNT = 20;

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function createStake(Config calldata config)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (uint64 stakeId)
    {
        stakeId = _nextStakeId++;

        uint64 configId = _applyConfig(stakeId, config);

        emit StakeCreated(stakeId, configId);
    }

    function updateStake(uint64 stakeId, Config calldata config)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (isStakeDeleted[stakeId]) revert StakeNotExist();
        if (stakeIdToCurrentConfigId[stakeId] == 0) revert StakeNotExist();

        uint64 configId = _applyConfig(stakeId, config);

        emit StakeUpdated(stakeId, configId);
    }

    function deleteStake(uint64 stakeId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (isStakeDeleted[stakeId]) revert StakeNotExist();
        if (stakeIdToCurrentConfigId[stakeId] == 0) revert StakeNotExist();

        isStakeDeleted[stakeId] = true;

        emit StakeDeleted(stakeId);
    }

    function _applyConfig(uint64 stakeId, Config calldata config)
        internal
        returns (uint64 configId)
    {
        _validateConfig(config);

        configId = _storeConfig(config);

        stakeIdToCurrentConfigId[stakeId] = configId;
    }

    function _validateConfig(Config calldata config) private pure {
        if (!RipsMath.isPowerOfTwo(config.ticketCap)) revert TicketCapNotPowerOfTwo();
        if (config.tiers.length == 0) revert InvalidTierCount();
        if (config.tiers.length > MAX_TIER_COUNT) revert InvalidTierCount();

        uint256 totalPrizeCount = 0;
        uint256 totalPrizePool = 0;

        for (uint256 i = 0; i < config.tiers.length; i++) {
            PrizeTier calldata tier = config.tiers[i];

            if (tier.minPrize > tier.maxPrize) revert InvalidPrizeRange();
            if (i > 0 && tier.prizeCount > config.tiers[i - 1].prizeCount) {
                revert TiersNotSortedByCount();
            }

            totalPrizeCount += tier.prizeCount;
            totalPrizePool += (uint256(tier.prizeCount)
                    * (uint256(tier.minPrize) + uint256(tier.maxPrize))) / 2;
        }

        if (config.feePercent > FEE_BASE) revert FeeTooHigh();
        if (totalPrizeCount != config.ticketCap) revert PrizeCountMismatch();
        uint256 totalRevenue = uint256(config.ticketCap) * config.ticketCost;
        uint256 protocolFee = (totalRevenue * config.feePercent) / FEE_BASE;
        if (totalPrizePool != totalRevenue - protocolFee) revert PrizePoolMismatch();
    }

    function _storeConfig(Config calldata config) private returns (uint64 configId) {
        configId = _nextConfigId++;

        Config storage newConfig = configIdToConfig[configId];
        newConfig.currency = config.currency;
        newConfig.ticketCap = config.ticketCap;
        newConfig.duration = config.duration;
        newConfig.ticketCost = config.ticketCost;
        newConfig.feePercent = config.feePercent;

        uint64 cumulative = 0;
        uint64[] storage boundaries = configIdToTierBoundaries[configId];

        for (uint256 i = 0; i < config.tiers.length; i++) {
            PrizeTier calldata tier = config.tiers[i];

            newConfig.tiers.push(tier);

            cumulative += tier.prizeCount;
            boundaries.push(cumulative);
        }
    }
}
