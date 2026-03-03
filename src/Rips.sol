// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./modules/RipsVrf.sol";
import "./modules/RipsMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Rips is RipsVrf, ReentrancyGuard {
    constructor(
        address vrfCoordinator,
        uint256 subscriptionId,
        bytes32 keyHash,
        uint32 callbackGasLimit,
        address initialOwner,
        uint256 initialFeePercent
    ) RipsVrf(vrfCoordinator, subscriptionId, keyHash, callbackGasLimit) {
        if (initialOwner == address(0)) revert ZeroAddress();

        transferOwnership(initialOwner);

        setFeeRecipient(initialOwner);
        setProtocolFee(initialFeePercent);
    }

    function buyTickets(
        uint256 stakeId,
        uint256 ticketCount
    ) external payable whenNotPaused nonReentrant {
        (
            uint256 roundId,
            Round storage round,
            StakeConfig storage config
        ) = _resolveActiveRoundAndStake(stakeId);

        _validateBuyTickets(ticketCount, config);

        uint256 toBuy = _getTicketsToBuy(round, config, ticketCount);

        _purchaseTickets(roundId, round, toBuy);

        if (round.ticketsSold == config.ticketCap) {
            _handleSoldOut(stakeId, round);
        }

        uint256 excess = ticketCount - toBuy;
        if (excess > 0) {
            _refund(roundId, msg.sender, excess * config.ticketCost);
        }
    }

    function _validateBuyTickets(
        uint ticketCount,
        StakeConfig storage config
    ) internal {
        if (ticketCount == 0) revert ZeroTickets();

        if (msg.value != ticketCount * config.ticketCost)
            revert IncorrectPayment();
    }

    function _getTicketsToBuy(
        Round storage round,
        StakeConfig storage config,
        uint ticketCount
    ) internal view returns (uint) {
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
        uint roundId,
        Round storage round,
        uint ticketsToBuy
    ) internal {
        uint256 startTicket = round.ticketsSold;

        round.ticketsSold += ticketsToBuy;

        _storeTicketRanges(roundId, msg.sender, startTicket, ticketsToBuy);

        emit TicketsPurchased(roundId, msg.sender, startTicket, ticketsToBuy);
    }

    function _resolveActiveRoundAndStake(
        uint256 stakeId
    )
        private
        returns (
            uint256 roundId,
            Round storage round,
            StakeConfig storage stakeConfig
        )
    {
        roundId = _stakeToActiveRound[stakeId];

        if (roundId == 0) revert StakeNotExist();

        round = _rounds[roundId];
        // TODO: consider is it safe to not check stakeConfig
        stakeConfig = _stakeConfigs[stakeId];

        if (block.timestamp >= round.startTime + stakeConfig.duration) {
            if (_stakeDeleted[stakeId]) revert StakeNotExist();

            roundId = _createRound(stakeId);
        }
    }

    function claimPrizes(
        uint256 roundId,
        uint256 startIndex,
        uint256 maxRanges
    ) external nonReentrant {
        Round storage round = _rounds[roundId];
        if (round.status != RoundStatus.Finalized) revert RoundNotFinalized();

        TicketRange[] storage ranges = _userTickets[roundId][msg.sender];
        if (startIndex >= ranges.length) revert InvalidStartIndex();

        StakeConfig storage config = _stakeConfigs[round.stakeId];
        uint256 n = config.ticketCap;
        uint256 a = round.randomA;
        uint256 b = round.randomB;

        uint256 totalPrize = 0;
        uint256 endIndex = startIndex + maxRanges;
        if (endIndex > ranges.length) endIndex = ranges.length;

        for (uint256 i = startIndex; i < endIndex; i++) {
            if (ranges[i].claimed) continue;

            for (uint256 j = 0; j < ranges[i].count; j++) {
                uint256 ticketNum = ranges[i].start + j;
                uint256 prizeNum = RipsMath.calculatePrizeNumber(
                    ticketNum,
                    a,
                    b,
                    n
                );
                totalPrize += RipsMath.calculatePrizeAmount(prizeNum, config);
            }

            ranges[i].claimed = true;
        }

        if (totalPrize > 0) {
            uint256 protocolFee = (totalPrize * protocolFeePercent) / 10000;
            uint256 userPrize = totalPrize - protocolFee;

            if (protocolFee > 0) {
                (bool feeSuccess, ) = feeRecipient.call{value: protocolFee}("");
                if (!feeSuccess) revert FeeTransferFailed();
            }

            (bool prizeSuccess, ) = msg.sender.call{value: userPrize}("");
            if (!prizeSuccess) revert PrizeTransferFailed();

            emit PrizesClaimed(roundId, msg.sender, userPrize);
        }
    }

    function requestRefund(uint256 roundId) external nonReentrant {
        Round storage round = _rounds[roundId];
        StakeConfig storage config = _stakeConfigs[round.stakeId];

        if (round.status != RoundStatus.Active) revert RoundNotExpired();
        if (block.timestamp < round.startTime + config.duration)
            revert RoundNotExpired();
        if (_hasRefunded[roundId][msg.sender]) revert AlreadyRefunded();

        TicketRange[] storage ranges = _userTickets[roundId][msg.sender];
        uint256 totalTickets = 0;
        for (uint256 i = 0; i < ranges.length; i++) {
            totalTickets += ranges[i].count;
        }

        if (totalTickets == 0) revert NoTicketsToRefund();

        _hasRefunded[roundId][msg.sender] = true;
        _refund(roundId, msg.sender, totalTickets * config.ticketCost);
    }

    function getUserTickets(
        uint256 roundId,
        address user
    ) external view returns (TicketRange[] memory) {
        return _userTickets[roundId][user];
    }

    function isRoundActive(uint256 roundId) external view returns (bool) {
        Round storage round = _rounds[roundId];

        if (round.status != RoundStatus.Active) return false;

        StakeConfig storage config = _stakeConfigs[round.stakeId];

        return block.timestamp < round.startTime + config.duration;
    }

    function _refund(uint256 roundId, address to, uint256 amount) private {
        (bool success, ) = to.call{value: amount}("");

        if (!success) revert RefundFailed();

        emit RefundIssued(roundId, to, amount);
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
            uint256 rangeSize = remaining > MAX_TICKETS_PER_RANGE
                ? MAX_TICKETS_PER_RANGE
                : remaining;
            ranges.push(
                TicketRange({
                    start: uint96(currentStart),
                    count: uint96(rangeSize),
                    claimed: false
                })
            );
            currentStart += rangeSize;
            remaining -= rangeSize;
        }
    }
}
