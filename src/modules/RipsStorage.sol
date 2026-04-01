// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../interfaces/IRips.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

abstract contract RipsStorage is IRips, VRFConsumerBaseV2Plus {
    uint256 public constant MAX_TICKETS_PER_RANGE = 1000;

    address public feeRecipient;
    uint16 public baseFeePercent;

    uint256 internal _nextStakeId = 1;
    uint256 internal _nextRoundId = 1;

    mapping(uint256 stakeId => StakeConfig config) internal _stakeConfigs;
    mapping(uint256 stakeId => uint64[] boundaries) internal _tierBoundaries;
    mapping(uint256 stakeId => bool deleted) internal _stakeDeleted;
    mapping(uint256 stakeId => StakeConfig config) internal _pendingConfigs;
    mapping(uint256 stakeId => uint64[] boundaries) internal _pendingTierBoundaries;
    mapping(uint256 stakeId => bool hasPending) internal _hasPendingConfig;
    mapping(uint256 roundId => Round round) internal _rounds;
    mapping(uint256 stakeId => uint256 roundId) internal _stakeToActiveRound;
    mapping(uint256 roundId => mapping(address buyer => TicketRange[] ranges)) internal
        _userTickets;
    mapping(uint256 roundId => mapping(address buyer => uint256 ticketCount)) internal
        _userTicketCount;
    mapping(uint256 roundId => mapping(address user => bool refunded)) internal _hasRefunded;

    mapping(address referrer => ReferrerStats stats) internal _referrerStats;
    ReferralTier[] internal _referralTiers;
}
