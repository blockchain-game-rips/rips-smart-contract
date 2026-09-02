// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RipsUtils} from "../common/RipsUtils.sol";
import {RipsReferral} from "../modules/RipsReferral.sol";
import {RipsMath} from "../libraries/RipsMath.sol";

abstract contract RipsClaimPayout is RipsUtils, RipsReferral {
    mapping(uint256 ripId => mapping(address user => uint64 chunkIndex)) public nextClaimChunkIndex;

    function claimPayout(uint256 ripId, uint256 maxChunks, address recipient, address referrer) external nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        if (maxChunks == 0) revert ZeroMaxChunks();
        if (msg.sender != recipient && !_isPrivileged(msg.sender)) revert NotRecipientOrOwner();

        Rip storage rip = ripIdToRip[ripId];
        if (rip.vrfRequestStatus != VrfRequestStatus.Fulfilled) revert RipNotFulfilled();

        EntryChunk[] storage chunks = userEntryChunks[ripId][recipient];
        uint64 startIndex = nextClaimChunkIndex[ripId][recipient];
        uint64 endIndex = _resolveClaimRange(chunks.length, startIndex, maxChunks);

        nextClaimChunkIndex[ripId][recipient] = endIndex;

        Config storage config = configIdToConfig[rip.configId];

        (uint64 entryCount, uint256 totalPayout) = _calculateChunkRangePayout(chunks, startIndex, endIndex, rip, config);

        _distributePayout(ripId, config, recipient, referrer, entryCount, totalPayout);
    }

    function _distributePayout(
        uint256 ripId,
        Config storage config,
        address recipient,
        address referrer,
        uint64 entryCount,
        uint256 payout
    ) private {
        address currency = config.currency;

        uint256 entryRevenue = entryCount * config.entryPrice;
        uint256 protocolFee = (entryRevenue * config.feeBps) / FEE_BASE;

        // even if protocolFee == 0, update referrer volume
        uint256 referrerFee = _collectReferrerFee(referrer, currency, protocolFee, entryRevenue);

        if (protocolFee > 0) {
            uint256 remainingFee = protocolFee - referrerFee;

            if (remainingFee > 0) {
                protocolFeeAccrued[currency] += remainingFee;
                emit ProtocolFeeAccrued(ripId, remainingFee);
            }

            if (referrerFee > 0) {
                referrerFeeAccrued[referrer][currency] += referrerFee;
                emit ReferralFeeAccrued(ripId, referrer, referrerFee);
            }
        }

        if (payout > 0) {
            _transfer(currency, recipient, payout);
        }

        emit PayoutClaimed(ripId, recipient, referrer, entryCount, payout);
    }

    function _resolveClaimRange(uint256 chunkCount, uint64 startIndex, uint256 maxChunks)
        private
        pure
        returns (uint64 endIndex)
    {
        if (startIndex >= chunkCount) revert NothingToClaim();

        uint256 available = chunkCount - startIndex;

        return startIndex + uint64(maxChunks > available ? available : maxChunks);
    }

    function _calculateChunkRangePayout(
        EntryChunk[] storage chunks,
        uint64 startIndex,
        uint64 endIndex,
        Rip storage rip,
        Config storage config
    ) private view returns (uint64 entryCount, uint256 totalPayout) {
        uint64 a = rip.randomA;
        uint64 b = rip.randomB;
        uint64 n = config.entryCap;
        PayoutTier[] memory tiers = config.tiers;
        uint64[] memory bounds = configIdToTierBoundaries[rip.configId];

        for (uint256 i = startIndex; i < endIndex; i++) {
            uint256 chunkStart = chunks[i].start;
            uint64 count = chunks[i].count;

            for (uint256 j = 0; j < count; j++) {
                totalPayout += RipsMath.calculateEntryPayout(chunkStart + j + 1, a, b, n, tiers, bounds);
            }

            entryCount += count;
        }
    }
}
