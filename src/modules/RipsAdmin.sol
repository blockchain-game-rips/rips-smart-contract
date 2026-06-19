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

    function createPreset(Config calldata config)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        returns (uint64 presetId)
    {
        presetId = _nextPresetId++;

        uint64 configId = _applyConfig(presetId, config);

        emit PresetCreated(presetId, configId);
    }

    function updatePreset(uint64 presetId, Config calldata config)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (isPresetDeleted[presetId]) revert PresetNotExist();
        if (presetIdToCurrentConfigId[presetId] == 0) revert PresetNotExist();

        uint64 configId = _applyConfig(presetId, config);

        emit PresetUpdated(presetId, configId);
    }

    function deletePreset(uint64 presetId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (isPresetDeleted[presetId]) revert PresetNotExist();
        if (presetIdToCurrentConfigId[presetId] == 0) revert PresetNotExist();

        isPresetDeleted[presetId] = true;

        emit PresetDeleted(presetId);
    }

    function _applyConfig(uint64 presetId, Config calldata config)
        internal
        returns (uint64 configId)
    {
        _validateConfig(config);

        configId = _storeConfig(config);

        presetIdToCurrentConfigId[presetId] = configId;
    }

    function _validateConfig(Config calldata config) private pure {
        if (!RipsMath.isPowerOfTwo(config.entryCap)) revert EntryCapNotPowerOfTwo();
        if (config.tiers.length == 0) revert InvalidTierCount();
        if (config.tiers.length > MAX_TIER_COUNT) revert InvalidTierCount();

        uint256 totalEntryCount = 0;
        uint256 totalPayoutPool = 0;

        for (uint256 i = 0; i < config.tiers.length; i++) {
            PayoutTier calldata tier = config.tiers[i];

            if (tier.minPayout > tier.maxPayout) revert InvalidPayoutRange();
            if (tier.payoutCount == 1 && tier.minPayout != tier.maxPayout) {
                revert InvalidPayoutRange();
            }
            if (i > 0 && tier.payoutCount > config.tiers[i - 1].payoutCount) {
                revert TiersNotSortedByPayoutCount();
            }

            totalEntryCount += tier.payoutCount;
            totalPayoutPool += (uint256(tier.payoutCount)
                    * (uint256(tier.minPayout) + uint256(tier.maxPayout))) / 2;
        }

        if (config.feePercent > FEE_BASE) revert FeeTooHigh();
        if (totalEntryCount != config.entryCap) revert PayoutCountMismatch();
        uint256 totalRevenue = uint256(config.entryCap) * config.entryPrice;
        uint256 protocolFee = (totalRevenue * config.feePercent) / FEE_BASE;
        if (totalPayoutPool != totalRevenue - protocolFee) revert PayoutPoolMismatch();
    }

    function _storeConfig(Config calldata config) private returns (uint64 configId) {
        configId = _nextConfigId++;

        Config storage newConfig = configIdToConfig[configId];
        newConfig.currency = config.currency;
        newConfig.entryCap = config.entryCap;
        newConfig.duration = config.duration;
        newConfig.entryPrice = config.entryPrice;
        newConfig.feePercent = config.feePercent;

        uint64 cumulative = 0;
        uint64[] storage boundaries = configIdToTierBoundaries[configId];

        for (uint256 i = 0; i < config.tiers.length; i++) {
            PayoutTier calldata tier = config.tiers[i];

            newConfig.tiers.push(tier);

            cumulative += tier.payoutCount;
            boundaries.push(cumulative);
        }
    }
}
