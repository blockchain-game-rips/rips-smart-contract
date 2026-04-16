// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RipsUtils} from "../common/RipsUtils.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract RipsBuyTickets is RipsUtils, Pausable {
    using SafeERC20 for IERC20;

    uint64 public constant MAX_TICKETS_PER_RANGE = 1000;

    function buyTickets(uint64 stakeId, uint64 ticketCount, address recipient)
        external
        payable
        whenNotPaused
    {
        if (recipient == address(0)) revert ZeroAddress();
        if (ticketCount == 0) revert ZeroTickets();

        (uint256 roundId, Round storage round, Config storage config) =
            _resolveRoundAndConfig(stakeId);

        uint64 toBuy = _getTicketsToBuy(round, config, ticketCount);

        _purchaseTickets(roundId, round, recipient, toBuy);

        uint256 nativeExcess = _receivePayment(config, toBuy, msg.sender);

        if (nativeExcess > 0) {
            _sendNative(recipient, nativeExcess);
        }
    }

    function _resolveRoundAndConfig(uint64 stakeId)
        private
        returns (uint256 roundId, Round storage round, Config storage config)
    {
        roundId = stakeIdToCurrentRoundId[stakeId];

        if (roundId != 0) {
            round = roundIdToRound[roundId];
            config = configIdToConfig[round.configId];

            // round is filling
            if (!_isExpired(round, config) && !_isSoldOut(round, config)) {
                return (roundId, round, config);
            }
        }

        if (isStakeDeleted[stakeId]) revert StakeNotExist();

        // stake is fresh, no round yet
        if (roundId == 0) {
            uint64 configId = stakeIdToCurrentConfigId[stakeId];

            // ticketCap is guaranteed non-zero by isPowerOfTwo validation
            if (configIdToConfig[configId].ticketCap == 0) revert StakeNotExist();
        }

        // round is sold out or expired
        return _createRound(stakeId);
    }

    function _createRound(uint64 stakeId)
        private
        returns (uint256 roundId, Round storage round, Config storage config)
    {
        roundId = _nextRoundId++;
        round = roundIdToRound[roundId];

        uint64 configId = stakeIdToCurrentConfigId[stakeId];
        config = configIdToConfig[configId];

        round.stakeId = uint64(stakeId);
        round.configId = uint64(configId);
        round.startTime = uint40(block.timestamp);
        round.vrfRequestStatus = VrfRequestStatus.NotRequested;

        stakeIdToCurrentRoundId[stakeId] = roundId;

        emit RoundCreated(roundId, stakeId, configId);
    }

    function _getTicketsToBuy(Round storage round, Config storage config, uint64 ticketCount)
        private
        view
        returns (uint64)
    {
        uint64 available = config.ticketCap - round.ticketsSold;

        return ticketCount > available ? available : ticketCount;
    }

    function _purchaseTickets(
        uint256 roundId,
        Round storage round,
        address recipient,
        uint64 ticketsToBuy
    ) private {
        uint64 startTicket = round.ticketsSold;

        round.ticketsSold += ticketsToBuy;

        _storeTicketRanges(roundId, recipient, startTicket, ticketsToBuy);

        emit TicketsPurchased(roundId, recipient, ticketsToBuy, startTicket);
    }

    function _storeTicketRanges(
        uint256 roundId,
        address buyer,
        uint64 startTicket,
        uint64 ticketCount
    ) private {
        TicketRange[] storage ranges = _userTickets[roundId][buyer];
        uint64 remaining = ticketCount;
        uint64 currentStart = startTicket;

        while (remaining > 0) {
            uint64 rangeSize = remaining > MAX_TICKETS_PER_RANGE ? MAX_TICKETS_PER_RANGE : remaining;

            ranges.push(
                TicketRange({start: uint64(currentStart), count: uint64(rangeSize), claimed: false})
            );
            currentStart += rangeSize;
            remaining -= rangeSize;
        }

        _userTicketCount[roundId][buyer] += ticketCount;
    }

    function _receivePayment(Config storage config, uint256 toBuy, address from)
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
}
