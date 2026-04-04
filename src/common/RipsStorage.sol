// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../interfaces/IRips.sol";

abstract contract RipsStorage is IRips {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    mapping(address currency => uint256 amount) public protocolFeeAccrued;
    mapping(address referrer => mapping(address currency => uint256 amount)) public
        referrerFeeAccrued;

    uint256 internal _nextStakeId = 1;
    uint256 internal _nextRoundId = 1;
    uint256 internal _nextConfigId = 1;

    mapping(uint256 configId => Config config) public configIdToConfig;
    mapping(uint256 configId => uint64[] boundaries) public configIdToTierBoundaries;

    mapping(uint256 roundId => Round round) public roundIdToRound;

    mapping(uint256 stakeId => uint256 configId) public stakeIdToCurrentConfigId;
    mapping(uint256 stakeId => uint256 roundId) public stakeIdToCurrentRoundId;
    mapping(uint256 stakeId => bool deleted) public isStakeDeleted;

    mapping(uint256 roundId => mapping(address buyer => TicketRange[] ranges)) internal
        _userTickets;
    mapping(uint256 roundId => mapping(address buyer => uint256 ticketCount)) internal
        _userTicketCount;

    mapping(uint256 roundId => uint256 requestTimestamp) internal _roundIdToRequestTimestamp;
}
