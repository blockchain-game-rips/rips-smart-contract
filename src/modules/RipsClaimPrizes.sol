// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RipsUtils} from "../common/RipsUtils.sol";
import {RipsReferral} from "../modules/RipsReferral.sol";
import {RipsMath} from "../libraries/RipsMath.sol";

abstract contract RipsClaimPrizes is RipsUtils, RipsReferral {
    function claimPrizes(
        uint256 roundId,
        uint256 startIndex,
        uint256 maxRanges,
        address recipient,
        address referrer
    ) external {
        if (recipient == address(0)) revert ZeroAddress();
        if (msg.sender != recipient && !_isPrivileged(msg.sender)) revert NotRecipientOrOwner();

        Round storage round = roundIdToRound[roundId];
        if (round.vrfRequestStatus != VrfRequestStatus.Fulfilled) revert RoundNotFulfilled();

        TicketRange[] storage ranges = userTickets[roundId][recipient];
        if (startIndex >= ranges.length) revert InvalidStartIndex();

        Config storage config = configIdToConfig[round.configId];

        (uint64 ticketCount, uint256 totalPrize) =
            _accumulateClaimedPrizes(ranges, startIndex, maxRanges, round, config);

        if (totalPrize > 0) {
            _distributePrize(roundId, round, recipient, referrer, ticketCount, totalPrize);
        }
    }

    function _distributePrize(
        uint256 roundId,
        Round storage round,
        address recipient,
        address referrer,
        uint64 ticketCount,
        uint256 prize
    ) private {
        Config storage config = configIdToConfig[round.configId];
        address currency = config.currency;

        uint256 ticketRevenue = ticketCount * config.ticketCost;
        uint256 protocolFee = (ticketRevenue * config.feePercent) / FEE_BASE;

        // even if protocolFee == 0, update referrer volume
        uint256 referrerFee = _collectReferrerFee(referrer, currency, protocolFee, ticketRevenue);

        if (protocolFee > 0) {
            uint256 remainingFee = protocolFee - referrerFee;

            if (remainingFee > 0) {
                protocolFeeAccrued[currency] += remainingFee;
                emit ProtocolFeeAccrued(roundId, remainingFee);
            }

            if (referrerFee > 0) {
                referrerFeeAccrued[referrer][currency] += referrerFee;
                emit ReferralFeeAccrued(roundId, referrer, referrerFee);
            }
        }

        _transfer(currency, recipient, prize);

        emit PrizesClaimed(roundId, recipient, referrer, ticketCount, prize);
    }

    function _accumulateClaimedPrizes(
        TicketRange[] storage ranges,
        uint256 startIndex,
        uint256 maxRanges,
        Round storage round,
        Config storage config
    ) private returns (uint64 ticketCount, uint256 totalPrize) {
        uint64 a = round.randomA;
        uint64 b = round.randomB;
        uint64 n = config.ticketCap;
        PrizeTier[] memory tiers = config.tiers;
        uint64[] memory bounds = configIdToTierBoundaries[round.configId];

        uint256 endIndex = startIndex + maxRanges;
        if (endIndex > ranges.length) endIndex = ranges.length;

        for (uint256 i = startIndex; i < endIndex; i++) {
            if (ranges[i].claimed) continue;

            uint256 rangeStart = ranges[i].start;
            uint64 count = ranges[i].count;

            for (uint256 j = 0; j < count; j++) {
                totalPrize += RipsMath.calculateTicketPrize(
                    rangeStart + j + 1, a, b, n, tiers, bounds
                );
            }

            ticketCount += count;

            ranges[i].claimed = true;
        }
    }
}
