// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./RipsStorage.sol";
import "./RipsMath.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

abstract contract RipsAdmin is RipsStorage, Pausable {
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function createStake(StakeConfig calldata config) external onlyOwner returns (uint256 stakeId) {
        _validateStakeConfig(config);

        stakeId = _nextStakeId++;

        _storeStakeConfig(stakeId, config);

        _createRound(stakeId);

        emit StakeCreated(stakeId);
    }

    function _validateStakeConfig(StakeConfig calldata config) private pure {
        if (!RipsMath.isPowerOfTwo(config.ticketCap)) {
            revert TicketCapNotPowerOfTwo();
        }
        if (config.prizeDistribution.length == 0) {
            revert EmptyPrizeDistribution();
        }

        uint256 totalPrizeCount = 0;
        uint256 totalPrizePool = 0;

        for (uint256 i = 0; i < config.prizeDistribution.length; i++) {
            PrizeTier calldata tier = config.prizeDistribution[i];
            if (tier.minPrize > tier.maxPrize) revert InvalidPrizeRange();
            totalPrizeCount += tier.prizeCount;
            totalPrizePool += (uint256(tier.prizeCount)
                    * (uint256(tier.minPrize) + uint256(tier.maxPrize))) / 2;
        }

        if (totalPrizeCount != config.ticketCap) revert PrizeCountMismatch();
        if (totalPrizePool != config.ticketCap * config.ticketCost) {
            revert PrizePoolMismatch();
        }
        if (config.feePercent > 10000) revert FeeTooHigh();
    }

    function _storeStakeConfig(uint256 stakeId, StakeConfig calldata config) private {
        StakeConfig storage newConfig = _stakeConfigs[stakeId];
        newConfig.currency = config.currency;
        newConfig.ticketCap = config.ticketCap;
        newConfig.duration = config.duration;
        newConfig.ticketCost = config.ticketCost;
        newConfig.feePercent = config.feePercent;

        uint64 cumulative = 0;

        for (uint256 i = 0; i < config.prizeDistribution.length; i++) {
            newConfig.prizeDistribution.push(config.prizeDistribution[i]);

            cumulative += config.prizeDistribution[i].prizeCount;
            _tierBoundaries[stakeId].push(cumulative);
        }
    }

    function updateStake(uint256 stakeId, StakeConfig calldata config) external onlyOwner {
        if (_stakeDeleted[stakeId]) revert StakeNotExist();
        if (_stakeToActiveRound[stakeId] == 0) revert StakeNotExist();

        _validateStakeConfig(config);

        _storePendingConfig(stakeId, config);

        emit StakeUpdated(stakeId);
    }

    function _storePendingConfig(uint256 stakeId, StakeConfig calldata config) private {
        delete _pendingConfigs[stakeId].prizeDistribution;
        delete _pendingTierBoundaries[stakeId];

        StakeConfig storage pending = _pendingConfigs[stakeId];
        pending.currency = config.currency;
        pending.ticketCap = config.ticketCap;
        pending.duration = config.duration;
        pending.ticketCost = config.ticketCost;
        pending.feePercent = config.feePercent;

        uint64 cumulative = 0;

        for (uint256 i = 0; i < config.prizeDistribution.length; i++) {
            pending.prizeDistribution.push(config.prizeDistribution[i]);

            cumulative += config.prizeDistribution[i].prizeCount;
            _pendingTierBoundaries[stakeId].push(cumulative);
        }

        _hasPendingConfig[stakeId] = true;
    }

    function _applyPendingConfig(uint256 stakeId) internal {
        if (!_hasPendingConfig[stakeId]) return;

        delete _stakeConfigs[stakeId].prizeDistribution;
        delete _tierBoundaries[stakeId];

        StakeConfig storage pending = _pendingConfigs[stakeId];
        StakeConfig storage active = _stakeConfigs[stakeId];

        active.currency = pending.currency;
        active.ticketCap = pending.ticketCap;
        active.duration = pending.duration;
        active.ticketCost = pending.ticketCost;
        active.feePercent = pending.feePercent;

        for (uint256 i = 0; i < pending.prizeDistribution.length; i++) {
            active.prizeDistribution.push(pending.prizeDistribution[i]);
            _tierBoundaries[stakeId].push(_pendingTierBoundaries[stakeId][i]);
        }

        delete _pendingConfigs[stakeId].prizeDistribution;
        delete _pendingTierBoundaries[stakeId];
        delete _hasPendingConfig[stakeId];
    }

    function deleteStake(uint256 stakeId) external onlyOwner {
        if (_stakeDeleted[stakeId]) revert StakeNotExist();
        _stakeDeleted[stakeId] = true;
        emit StakeDeleted(stakeId);
    }

    function setFeeRecipient(address newRecipient) public onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(newRecipient);
    }

    function _createRound(uint256 stakeId) internal returns (uint256 roundId) {
        _applyPendingConfig(stakeId);

        roundId = _nextRoundId++;

        Round storage round = _rounds[roundId];
        round.stakeId = uint64(stakeId);
        round.startTime = uint40(block.timestamp);
        round.status = RoundStatus.Active;

        _stakeToActiveRound[stakeId] = roundId;

        emit RoundCreated(roundId, stakeId);
    }
}
