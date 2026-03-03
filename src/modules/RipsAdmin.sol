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

    function createStake(
        StakeConfig calldata config
    ) external onlyOwner returns (uint256 stakeId) {
        if (!RipsMath.isPowerOfTwo(config.ticketCap)) revert TicketCapNotPowerOfTwo();
        if (config.prizeDistribution.length == 0) revert EmptyPrizeDistribution();

        uint256 totalWinners = 0;
        uint256 totalPrizePool = 0;

        for (uint256 i = 0; i < config.prizeDistribution.length; i++) {
            PrizeTier memory tier = config.prizeDistribution[i];
            if (tier.minPrize > tier.maxPrize) revert InvalidPrizeRange();
            totalWinners += tier.winnersInTier;
            totalPrizePool += (tier.winnersInTier * (tier.minPrize + tier.maxPrize)) / 2;
        }

        if (totalWinners != config.ticketCap) revert WinnersSumMismatch();
        if (totalPrizePool != config.ticketCap * config.ticketCost) revert PrizePoolMismatch();

        stakeId = _nextStakeId++;

        StakeConfig storage newConfig = _stakeConfigs[stakeId];
        newConfig.ticketCap = config.ticketCap;
        newConfig.duration = config.duration;
        newConfig.ticketCost = config.ticketCost;
        for (uint256 i = 0; i < config.prizeDistribution.length; i++) {
            newConfig.prizeDistribution.push(config.prizeDistribution[i]);
        }

        _createRound(stakeId);

        emit StakeCreated(stakeId, config.ticketCap, config.ticketCost);
    }

    function deleteStake(uint256 stakeId) external onlyOwner {
        if (_stakeDeleted[stakeId]) revert StakeAlreadyDeleted();
        _stakeDeleted[stakeId] = true;
        emit StakeDeleted(stakeId);
    }

    function updateProtocolFee(uint256 newFeePercent) external onlyOwner {
        if (newFeePercent > 10000) revert FeeTooHigh();
        protocolFeePercent = newFeePercent;
        emit ProtocolFeeUpdated(newFeePercent);
    }

    function updateFeeRecipient(address newRecipient) external onlyOwner {
        if (newRecipient == address(0)) revert InvalidFeeRecipient();
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(newRecipient);
    }

    function getStakeConfig(uint256 stakeId) external view returns (StakeConfig memory) {
        return _stakeConfigs[stakeId];
    }

    function _createRound(uint256 stakeId) internal {
        uint256 roundId = _nextRoundId++;

        Round storage round = _rounds[roundId];
        round.stakeId = stakeId;
        round.startTime = block.timestamp;
        round.state = RoundState.Active;

        _stakeCurrentRound[stakeId] = roundId;

        emit RoundCreated(roundId, stakeId, block.timestamp);
    }
}
