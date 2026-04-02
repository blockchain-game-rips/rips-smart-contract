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

    function createStake(Config calldata config) external onlyOwner returns (uint256 stakeId) {
        stakeId = _nextStakeId++;

        _applyConfig(stakeId, config);

        _createRound(stakeId);

        emit StakeCreated(stakeId);
    }

    function updateStake(uint256 stakeId, Config calldata config) external onlyOwner {
        if (_stakeDeleted[stakeId]) revert StakeNotExist();
        if (_stakeIdToCurrentRoundId[stakeId] == 0) revert StakeNotExist();

        _applyConfig(stakeId, config);

        emit StakeUpdated(stakeId);
    }

    function _applyConfig(uint256 stakeId, Config calldata config) internal {
        _validateConfig(config);

        uint256 configId = _storeConfig(config);

        _stakeIdToCurrentConfigId[stakeId] = configId;
    }

    function _validateConfig(Config calldata config) private pure {
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

    function _storeConfig(Config calldata config) private returns (uint256 configId) {
        configId = _nextConfigId++;

        Config storage newConfig = _configIdToConfig[configId];
        newConfig.currency = config.currency;
        newConfig.ticketCap = config.ticketCap;
        newConfig.duration = config.duration;
        newConfig.ticketCost = config.ticketCost;
        newConfig.feePercent = config.feePercent;

        uint64 cumulative = 0;

        for (uint256 i = 0; i < config.prizeDistribution.length; i++) {
            newConfig.prizeDistribution.push(config.prizeDistribution[i]);

            cumulative += config.prizeDistribution[i].prizeCount;
            _configIdToTierBoundaries[configId].push(cumulative);
        }
    }

    function deleteStake(uint256 stakeId) external onlyOwner {
        if (_stakeDeleted[stakeId]) revert StakeNotExist();
        _stakeDeleted[stakeId] = true;
        emit StakeDeleted(stakeId);
    }

    function setBaseFeePercent(uint16 newBaseFeePercent) external onlyOwner {
        if (newBaseFeePercent > 10000) revert FeeTooHigh();
        baseFeePercent = newBaseFeePercent;
        emit BaseFeePercentUpdated(newBaseFeePercent);
    }

    function setReferrerCustomFee(address referrer, uint16 customFeePercent) external onlyOwner {
        if (referrer == address(0)) revert ZeroAddress();
        if (customFeePercent > 10000) revert FeeTooHigh();
        _referrerToReferrerStats[referrer].customFeePercent = customFeePercent;
        emit ReferrerCustomFeeSet(referrer, customFeePercent);
    }

    function setReferralTiers(ReferralTier[] calldata tiers) external onlyOwner {
        if (tiers.length == 0) revert ReferralTiersEmpty();

        for (uint256 i = 1; i < tiers.length; i++) {
            if (tiers[i].minVolume <= tiers[i - 1].minVolume) revert ReferralTiersNotSorted();
        }

        delete _referralTiers;

        for (uint256 i = 0; i < tiers.length; i++) {
            _referralTiers.push(tiers[i]);
        }

        emit ReferralTiersUpdated(tiers);
    }

    function setFeeRecipient(address newRecipient) public onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(newRecipient);
    }

    function _createRound(uint256 stakeId) internal returns (uint256 roundId) {
        roundId = _nextRoundId++;

        Round storage round = _roundIdToRound[roundId];
        round.stakeId = uint64(stakeId);
        round.configId = uint64(_stakeIdToCurrentConfigId[stakeId]);
        round.startTime = uint40(block.timestamp);
        round.status = RoundStatus.Active;

        _stakeIdToCurrentRoundId[stakeId] = roundId;

        emit RoundCreated(roundId, stakeId);
    }
}
