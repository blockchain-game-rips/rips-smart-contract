// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RipsUtils} from "../common/RipsUtils.sol";

abstract contract RipsRefund is RipsUtils {
    mapping(uint256 ripId => mapping(address user => bool refunded)) public hasRefunded;

    function refund(uint256 ripId, address recipient) external nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();

        Rip storage rip = ripIdToRip[ripId];
        if (rip.presetId == 0) revert RipNotExist();

        Config storage config = configIdToConfig[rip.configId];

        if (_ripState(ripId) != RipState.Refundable) revert RipNotExpired();
        if (hasRefunded[ripId][recipient]) revert AlreadyRefunded();

        uint64 entryCount = userEntryCount[ripId][recipient];
        if (entryCount == 0) revert NoEntriesToRefund();

        hasRefunded[ripId][recipient] = true;
        _transfer(config.currency, recipient, entryCount * config.entryPrice);

        emit RefundIssued(ripId, recipient, entryCount);
    }
}
