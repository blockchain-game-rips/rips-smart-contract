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
        if (!RipsMath.isPowerOfTwo(config.ticketCap)) {
            revert TicketCapNotPowerOfTwo();
        }
        if (config.prizeDistribution.length == 0) {
            revert EmptyPrizeDistribution();
        }

        uint256 totalPrizeCount = 0;
        uint256 totalPrizePool = 0;

        for (uint256 i = 0; i < config.prizeDistribution.length; i++) {
            PrizeTier memory tier = config.prizeDistribution[i];
            if (tier.minPrize > tier.maxPrize) revert InvalidPrizeRange();
            totalPrizeCount += tier.prizeCount;
            totalPrizePool += (tier.prizeCount * (tier.minPrize + tier.maxPrize)) / 2;
        }

        if (totalPrizeCount != config.ticketCap) revert PrizeCountMismatch();
        if (totalPrizePool != config.ticketCap * config.ticketCost) {
            revert PrizePoolMismatch();
        }

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
        if (_stakeDeleted[stakeId]) revert StakeNotExist();
        _stakeDeleted[stakeId] = true;
        emit StakeDeleted(stakeId);
    }

    function setProtocolFee(uint256 newFeePercent) public onlyOwner {
        if (newFeePercent > 10000) revert FeeTooHigh();
        protocolFeePercent = newFeePercent;
        emit ProtocolFeeUpdated(newFeePercent);
    }

    function setFeeRecipient(address newRecipient) public onlyOwner {
        if (newRecipient == address(0)) revert ZeroAddress();
        feeRecipient = newRecipient;
        emit FeeRecipientUpdated(newRecipient);
    }

    function _createRound(uint256 stakeId) internal returns (uint256 roundId) {
        roundId = _nextRoundId++;

        Round storage round = _rounds[roundId];
        round.stakeId = stakeId;
        round.startTime = block.timestamp;
        round.status = RoundStatus.Active;

        _stakeToActiveRound[stakeId] = roundId;

        emit RoundCreated(roundId, stakeId, block.timestamp);
    }
}
