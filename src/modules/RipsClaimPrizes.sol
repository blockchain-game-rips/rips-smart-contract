// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../common/RipsUtils.sol";
import "../modules/RipsReferral.sol";
import "../libraries/RipsMath.sol";

abstract contract RipsClaimPrizes is RipsUtils, RipsReferral {
    struct PrizeCalcParams {
        uint64 a;
        uint64 b;
        uint64 n;
        PrizeTier[] tiers;
        uint64[] bounds;
    }

    function claimPrizes(
        uint256 roundId,
        uint256 startIndex,
        uint256 maxRanges,
        address recipient,
        address referrer
    ) external {
        if (recipient == address(0)) revert ZeroAddress();
        if (msg.sender != recipient && msg.sender != owner()) revert NotRecipientOrOwner();

        Round storage round = roundIdToRound[roundId];
        if (round.status != RoundStatus.Finalized) revert RoundNotFinalized();

        TicketRange[] storage ranges = _userTickets[roundId][recipient];
        if (startIndex >= ranges.length) revert InvalidStartIndex();

        Config storage config = configIdToConfig[round.configId];

        (uint256 ticketCount, uint256 totalPrize) =
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
        uint256 ticketCount,
        uint256 prize
    ) private {
        Config storage config = configIdToConfig[round.configId];
        address currency = config.currency;

        uint256 ticketRevenue = ticketCount * config.ticketCost;
        uint256 protocolFee = (ticketRevenue * config.feePercent) / FEE_BASE;

        if (protocolFee > 0) {
            uint256 referrerFee = _collectReferrerFee(referrer, protocolFee, ticketRevenue);
            uint256 remainingFee = protocolFee - referrerFee;

            if (remainingFee > 0) {
                _transfer(currency, feeRecipient, remainingFee);
            }

            if (referrerFee > 0) {
                _transfer(currency, referrer, referrerFee);
                emit ReferralFeePaid(roundId, referrer, referrerFee);
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
    ) private returns (uint256 ticketCount, uint256 totalPrize) {
        PrizeCalcParams memory p = PrizeCalcParams({
            a: round.randomA,
            b: round.randomB,
            n: config.ticketCap,
            tiers: config.tiers,
            bounds: configIdToTierBoundaries[round.configId]
        });

        uint256 endIndex = startIndex + maxRanges;
        if (endIndex > ranges.length) endIndex = ranges.length;

        for (uint256 i = startIndex; i < endIndex; i++) {
            if (ranges[i].claimed) continue;

            uint256 rangeStart = ranges[i].start;
            uint256 count = ranges[i].count;

            for (uint256 j = 0; j < count; j++) {
                //TODO: try to pass memory struct and see gas consumption diff
                totalPrize += RipsMath.calculateTicketPrize(
                    rangeStart + j + 1, p.a, p.b, p.n, p.tiers, p.bounds
                );
            }

            ticketCount += count;

            ranges[i].claimed = true;
        }
    }
}
