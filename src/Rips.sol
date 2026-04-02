// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./modules/RipsVrf.sol";
import "./modules/RipsMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Rips is RipsVrf, ReentrancyGuard {
    using SafeERC20 for IERC20;

    constructor(
        address vrfCoordinator,
        uint256 vrfSubscriptionId,
        bytes32 vrfKeyHash,
        uint32 callbackGasLimit
    ) RipsVrf(vrfCoordinator, vrfSubscriptionId, vrfKeyHash, callbackGasLimit) {
        setFeeRecipient(msg.sender);
    }

    function buyTickets(uint256 stakeId, uint256 ticketCount, address recipient)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        if (recipient == address(0)) revert ZeroAddress();
        if (ticketCount == 0) revert ZeroTickets();

        (uint256 roundId, Round storage round, StakeConfig storage config) =
            _resolveActiveRoundAndStake(stakeId);

        uint256 toBuy = _getTicketsToBuy(round, config, ticketCount);

        _purchaseTickets(roundId, round, recipient, toBuy);

        if (round.ticketsSold == config.ticketCap) {
            _handleSoldOut(stakeId, round);
        }

        uint256 nativeExcess = _receivePayment(config, toBuy, msg.sender);

        if (nativeExcess > 0) {
            (bool success,) = msg.sender.call{value: nativeExcess}("");

            if (!success) revert ReturnExcessFailed();
        }
    }

    function _getTicketsToBuy(Round storage round, StakeConfig storage config, uint256 ticketCount)
        internal
        view
        returns (uint256)
    {
        uint256 available = config.ticketCap - round.ticketsSold;

        return ticketCount > available ? available : ticketCount;
    }

    function _handleSoldOut(uint256 stakeId, Round storage round) private {
        round.status = RoundStatus.SoldOut;

        if (_stakeDeleted[stakeId]) {
            _stakeToActiveRound[stakeId] = 0;
        } else {
            _createRound(stakeId);
        }
    }

    function _purchaseTickets(
        uint256 roundId,
        Round storage round,
        address recipient,
        uint256 ticketsToBuy
    ) internal {
        uint256 startTicket = round.ticketsSold;

        round.ticketsSold += uint32(ticketsToBuy);

        _storeTicketRanges(roundId, recipient, startTicket, ticketsToBuy);

        emit TicketsPurchased(roundId, recipient, ticketsToBuy, startTicket);
    }

    function _resolveActiveRoundAndStake(uint256 stakeId)
        private
        returns (uint256 roundId, Round storage round, StakeConfig storage stakeConfig)
    {
        roundId = _stakeToActiveRound[stakeId];

        if (roundId == 0) revert StakeNotExist();

        round = _rounds[roundId];
        // TODO: consider is it safe to not check stakeConfig
        stakeConfig = _stakeConfigs[stakeId];

        if (block.timestamp >= round.startTime + stakeConfig.duration) {
            if (_stakeDeleted[stakeId]) revert StakeNotExist();

            roundId = _createRound(stakeId);

            round = _rounds[roundId];
        }
    }

    function claimPrizes(
        uint256 roundId,
        uint256 startIndex,
        uint256 maxRanges,
        address recipient,
        address referrer
    ) external nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        if (msg.sender != recipient && msg.sender != owner()) revert NotRecipientOrOwner();

        //TODO: validation to separate function
        Round storage round = _rounds[roundId];
        if (round.status != RoundStatus.Finalized) revert RoundNotFinalized();

        TicketRange[] storage ranges = _userTickets[roundId][recipient];
        if (startIndex >= ranges.length) revert InvalidStartIndex();

        StakeConfig storage config = _stakeConfigs[round.stakeId];

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
        StakeConfig storage stakeConfig = _stakeConfigs[round.stakeId];
        address currency = stakeConfig.currency;

        uint256 protocolFee = (prize * stakeConfig.feePercent) / 10000;
        uint256 userPrize = prize - protocolFee;

        if (protocolFee > 0) {
            uint256 referrerFee = _collectReferrerFee(referrer, protocolFee, prize);
            uint256 remainingFee = protocolFee - referrerFee;

            if (remainingFee > 0) {
                if (_isNative(currency)) {
                    (bool feeSuccess,) = feeRecipient.call{value: remainingFee}("");
                    if (!feeSuccess) revert FeeTransferFailed();
                } else {
                    IERC20(currency).safeTransfer(feeRecipient, remainingFee);
                }
            }

            if (referrerFee > 0) {
                _sendPayment(currency, referrer, referrerFee);
                emit ReferralFeePaid(roundId, referrer, referrerFee);
            }
        }

        //TODO: ensure that protocol fee < 100%
        _sendPayment(currency, recipient, userPrize);

        emit PrizesClaimed(roundId, recipient, referrer, ticketCount, userPrize);
    }

    function _collectReferrerFee(address referrer, uint256 protocolFee, uint256 claimVolume)
        private
        returns (uint256 referrerFee)
    {
        if (referrer == address(0)) return 0;

        ReferrerStats storage stats = _referrerStats[referrer];

        if (stats.customFeePercent > 0) {
            return (protocolFee * stats.customFeePercent) / 10000;
        }

        if (_referralTiers.length == 0 && baseFeePercent == 0) return 0;

        uint32 currentMonth = uint32(block.timestamp / 30 days);

        if (stats.currentMonth < currentMonth) {
            uint16 prevNextFeePercent = stats.nextFeePercent;

            stats.activeFeePercent =
                (currentMonth == stats.currentMonth + 1) ? prevNextFeePercent : 0;
            stats.nextFeePercent = 0;
            stats.currMonthVolume = 0;
            stats.currentMonth = currentMonth;
        }

        stats.currMonthVolume += uint128(claimVolume);

        uint16 newNextFeePercent = _resolveTierFeePercent(stats.currMonthVolume);

        if (newNextFeePercent != stats.nextFeePercent) {
            stats.nextFeePercent = newNextFeePercent;
            emit ReferrerStatsUpdated(referrer, stats.activeFeePercent, newNextFeePercent);
        }

        uint16 effectiveFeePercent =
            stats.activeFeePercent > baseFeePercent ? stats.activeFeePercent : baseFeePercent;

        referrerFee = (protocolFee * effectiveFeePercent) / 10000;
    }

    function _resolveTierFeePercent(uint128 volume) private view returns (uint16 feePercent) {
        for (uint256 i = _referralTiers.length; i > 0; i--) {
            if (volume >= _referralTiers[i - 1].minVolume) {
                return _referralTiers[i - 1].feePercent;
            }
        }
    }

    function _receivePayment(StakeConfig storage config, uint256 toBuy, address from)
        private
        returns (uint256 nativeExcess)
    {
        uint256 requiredPayment = toBuy * config.ticketCost;
        address currency = config.currency;

        if (_isNative(currency)) {
            if (msg.value < requiredPayment) revert IncorrectPayment();

            nativeExcess = msg.value - requiredPayment;
        } else {
            if (msg.value != 0) revert EthSentForERC20();

            IERC20(currency).safeTransferFrom(from, address(this), requiredPayment);
        }
    }

    function _sendPayment(address currency, address to, uint256 amount) private {
        if (_isNative(currency)) {
            (bool success,) = to.call{value: amount}("");

            if (!success) revert PrizeTransferFailed();
        } else {
            IERC20(currency).safeTransfer(to, amount);
        }
    }

    struct PrizeCalcParams {
        uint256 a;
        uint256 b;
        uint256 n;
        PrizeTier[] tiers;
        uint64[] bounds;
    }

    function _accumulateClaimedPrizes(
        TicketRange[] storage ranges,
        uint256 startIndex,
        uint256 maxRanges,
        Round storage round,
        StakeConfig storage config
    ) private returns (uint256 ticketCount, uint256 totalPrize) {
        PrizeCalcParams memory p = PrizeCalcParams({
            a: round.randomA,
            b: round.randomB,
            n: config.ticketCap,
            tiers: config.prizeDistribution,
            bounds: _tierBoundaries[round.stakeId]
        });

        uint256 endIndex = startIndex + maxRanges;
        if (endIndex > ranges.length) endIndex = ranges.length;

        for (uint256 i = startIndex; i < endIndex; i++) {
            if (ranges[i].claimed) continue;

            uint256 rangeStart = ranges[i].start;
            uint256 count = ranges[i].count;

            for (uint256 j = 0; j < count; j++) {
                totalPrize += _calculateTicketPrize(rangeStart + j + 1, p);
            }

            ticketCount += count;

            ranges[i].claimed = true;
        }
    }

    function _calculateTicketPrize(uint256 ticketNumber, PrizeCalcParams memory p)
        private
        pure
        returns (uint256)
    {
        uint256 prizeNumber = (p.a * ticketNumber + p.b) % p.n + 1;

        for (uint256 t = 0; t < p.bounds.length; t++) {
            if (prizeNumber <= p.bounds[t]) {
                PrizeTier memory tier = p.tiers[t];
                uint256 rank = prizeNumber - (t == 0 ? 0 : p.bounds[t - 1]);

                if (tier.prizeCount == 1) return tier.minPrize;

                return tier.minPrize + ((tier.maxPrize - tier.minPrize) * (rank - 1))
                    / (tier.prizeCount - 1);
            }
        }

        revert();
    }

    function refund(uint256 roundId, address recipient) external nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();

        //TODO: move validation to separate function
        Round storage round = _rounds[roundId];

        uint256 stakeId = round.stakeId;
        if (stakeId == 0) revert RoundNotExist();

        StakeConfig storage config = _stakeConfigs[stakeId];

        if (!_isRoundExpired(round, config)) revert RoundNotExpired();
        if (_hasRefunded[roundId][recipient]) revert AlreadyRefunded();

        uint256 ticketsToRefund = _getTicketAmountToRefund(roundId, recipient);

        _hasRefunded[roundId][recipient] = true;
        _refund(
            roundId,
            config.currency,
            recipient,
            ticketsToRefund,
            ticketsToRefund * config.ticketCost
        );
    }

    function _getTicketAmountToRefund(uint256 roundId, address recipient)
        internal
        view
        returns (uint256)
    {
        uint256 totalTickets = _userTicketCount[roundId][recipient];

        if (totalTickets == 0) revert NoTicketsToRefund();

        return totalTickets;
    }

    function _isRoundExpired(Round storage round, StakeConfig storage config)
        internal
        view
        returns (bool)
    {
        if (
            (round.status == RoundStatus.Active)
                && (block.timestamp > round.startTime + config.duration)
        ) {
            return true;
        }

        return false;
    }

    function getUserTickets(uint256 roundId, address user)
        external
        view
        returns (TicketRange[] memory)
    {
        return _userTickets[roundId][user];
    }

    function _refund(
        uint256 roundId,
        address currency,
        address to,
        uint256 ticketCount,
        uint256 amount
    ) private {
        if (_isNative(currency)) {
            (bool success,) = to.call{value: amount}("");
            if (!success) revert RefundFailed();
        } else {
            IERC20(currency).safeTransfer(to, amount);
        }

        emit RefundIssued(roundId, to, ticketCount);
    }

    function _storeTicketRanges(
        uint256 roundId,
        address buyer,
        uint256 startTicket,
        uint256 ticketCount
    ) private {
        TicketRange[] storage ranges = _userTickets[roundId][buyer];
        uint256 remaining = ticketCount;
        uint256 currentStart = startTicket;

        while (remaining > 0) {
            uint256 rangeSize =
                remaining > MAX_TICKETS_PER_RANGE ? MAX_TICKETS_PER_RANGE : remaining;
            ranges.push(
                TicketRange({start: uint96(currentStart), count: uint96(rangeSize), claimed: false})
            );
            currentStart += rangeSize;
            remaining -= rangeSize;
        }

        _userTicketCount[roundId][buyer] += ticketCount;
    }

    function _isNative(address currency) private returns (bool) {
        return currency == address(0);
    }
}
