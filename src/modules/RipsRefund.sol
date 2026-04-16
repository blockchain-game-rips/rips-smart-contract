// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RipsUtils} from "../common/RipsUtils.sol";

abstract contract RipsRefund is RipsUtils {
    mapping(uint256 roundId => mapping(address user => bool refunded)) public hasRefunded;

    function refund(uint256 roundId, address recipient) external {
        if (recipient == address(0)) revert ZeroAddress();

        Round storage round = roundIdToRound[roundId];
        if (round.stakeId == 0) revert RoundNotExist();

        Config storage config = configIdToConfig[round.configId];

        if (!_isRoundRefundable(roundId, round, config)) revert RoundNotExpired();
        if (hasRefunded[roundId][recipient]) revert AlreadyRefunded();

        uint64 ticketCount = userTicketCount[roundId][recipient];
        if (ticketCount == 0) revert NoTicketsToRefund();

        hasRefunded[roundId][recipient] = true;
        _transfer(config.currency, recipient, ticketCount * config.ticketCost);

        emit RefundIssued(roundId, recipient, ticketCount);
    }

    function _isRoundRefundable(uint256 roundId, Round storage round, Config storage config)
        internal
        view
        returns (bool)
    {
        if (_isExpired(round, config) && !_isSoldOut(round, config)) return true;

        if (_isVrfRequestExpired(roundId) && round.vrfRequestStatus == VrfRequestStatus.Requested) {
            return true;
        }

        return false;
    }
}
