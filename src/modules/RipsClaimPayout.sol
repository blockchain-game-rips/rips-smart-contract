// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RipsUtils} from "../common/RipsUtils.sol";
import {RipsReferral} from "../modules/RipsReferral.sol";
import {RipsMath} from "../libraries/RipsMath.sol";

abstract contract RipsClaimPayout is RipsUtils, RipsReferral {
    function claimPayout(
        uint256 ripId,
        uint256 startIndex,
        uint256 maxChunks,
        address recipient,
        address referrer
    ) external nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        if (msg.sender != recipient && !_isPrivileged(msg.sender)) revert NotRecipientOrOwner();

        Rip storage rip = ripIdToRip[ripId];
        if (rip.vrfRequestStatus != VrfRequestStatus.Fulfilled) revert RipNotFulfilled();

        EntryChunk[] storage chunks = userEntryChunks[ripId][recipient];
        if (startIndex >= chunks.length) revert InvalidStartIndex();

        Config storage config = configIdToConfig[rip.configId];

        (uint64 entryCount, uint256 totalPayout) =
            _accumulateClaimedPayouts(chunks, startIndex, maxChunks, rip, config);

        if (entryCount > 0) {
            _distributePayout(ripId, rip, recipient, referrer, entryCount, totalPayout);
        }
    }

    function _distributePayout(
        uint256 ripId,
        Rip storage rip,
        address recipient,
        address referrer,
        uint64 entryCount,
        uint256 payout
    ) private {
        Config storage config = configIdToConfig[rip.configId];
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

    function _accumulateClaimedPayouts(
        EntryChunk[] storage chunks,
        uint256 startIndex,
        uint256 maxChunks,
        Rip storage rip,
        Config storage config
    ) private returns (uint64 entryCount, uint256 totalPayout) {
        uint64 a = rip.randomA;
        uint64 b = rip.randomB;
        uint64 n = config.entryCap;
        PayoutTier[] memory tiers = config.tiers;
        uint64[] memory bounds = configIdToTierBoundaries[rip.configId];

        uint256 available = chunks.length - startIndex;
        uint256 chunksToProcess = maxChunks > available ? available : maxChunks;
        uint256 endIndex = startIndex + chunksToProcess;

        for (uint256 i = startIndex; i < endIndex; i++) {
            if (chunks[i].claimed) continue;

            uint256 chunkStart = chunks[i].start;
            uint64 count = chunks[i].count;

            for (uint256 j = 0; j < count; j++) {
                totalPayout += RipsMath.calculateEntryPayout(
                    chunkStart + j + 1, a, b, n, tiers, bounds
                );
            }

            entryCount += count;

            chunks[i].claimed = true;
        }
    }
}
