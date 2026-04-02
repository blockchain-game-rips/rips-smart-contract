// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../interfaces/IRips.sol";

abstract contract RipsStorage is IRips {
    uint256 public constant MAX_TICKETS_PER_RANGE = 1000;

    address public feeRecipient;

    uint256 internal _nextStakeId = 1;
    uint256 internal _nextRoundId = 1;
    uint256 internal _nextConfigId = 1;

    mapping(uint256 configId => Config config) public configIdToConfig;
    mapping(uint256 configId => uint64[] boundaries) public configIdToTierBoundaries;

    // config that will be used when next round is created
    mapping(uint256 roundId => Round round) public roundIdToRound;

    mapping(uint256 stakeId => uint256 configId) public stakeIdToCurrentConfigId;
    mapping(uint256 stakeId => uint256 roundId) public stakeIdToCurrentRoundId;
    mapping(uint256 stakeId => bool deleted) public isStakeDeleted;

    mapping(uint256 roundId => mapping(address buyer => TicketRange[] ranges)) internal
        _userTickets;
    mapping(uint256 roundId => mapping(address buyer => uint256 ticketCount)) internal
        _userTicketCount;
    mapping(uint256 roundId => mapping(address user => bool refunded)) internal _hasRefunded;
}
