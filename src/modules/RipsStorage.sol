// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../interfaces/IRips.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

abstract contract RipsStorage is IRips, VRFConsumerBaseV2Plus {
    uint256 public constant MAX_TICKETS_PER_RANGE = 1000;

    address public feeRecipient;
    uint256 public protocolFeePercent;

    uint256 internal _nextStakeId;
    uint256 internal _nextRoundId;

    mapping(uint256 stakeId => StakeConfig config) internal _stakeConfigs;
    mapping(uint256 stakeId => bool deleted) internal _stakeDeleted;
    mapping(uint256 roundId => Round round) internal _rounds;
    mapping(uint256 stakeId => uint256 roundId) internal _stakeToActiveRound;
    mapping(uint256 roundId => mapping(address buyer => TicketRange[] ranges))
        internal _userTickets;
    mapping(uint256 roundId => mapping(address user => bool refunded))
        internal _hasRefunded;
}
