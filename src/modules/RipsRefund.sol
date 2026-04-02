// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../common/RipsUtils.sol";

abstract contract RipsRefund is RipsUtils {
    mapping(uint256 roundId => mapping(address user => bool refunded)) public hasRefunded;

    function refund(uint256 roundId, address recipient) external {
        if (recipient == address(0)) revert ZeroAddress();

        Round storage round = roundIdToRound[roundId];
        if (round.stakeId == 0) revert RoundNotExist();

        Config storage config = configIdToConfig[round.configId];

        if (!_isExpired(round, config) && !_isSoldOut(round, config)) revert RoundNotExpired();
        if (hasRefunded[roundId][recipient]) revert AlreadyRefunded();

        uint256 ticketCount = _userTicketCount[roundId][recipient];
        if (ticketCount == 0) revert NoTicketsToRefund();

        hasRefunded[roundId][recipient] = true;
        _transfer(config.currency, recipient, ticketCount * config.ticketCost);

        emit RefundIssued(roundId, recipient, ticketCount);
    }
}
