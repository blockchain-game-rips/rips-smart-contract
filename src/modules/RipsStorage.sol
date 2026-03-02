// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../interfaces/IRips.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

abstract contract RipsStorage is IRips, VRFConsumerBaseV2Plus {
    enum RoundState {
        Active,
        AwaitingVRF,
        Finalized,
        Expired
    }

    struct Round {
        uint256 stakeId;
        uint256 startTime;
        uint256 ticketsSold;
        RoundState state;
        uint256 vrfRequestId;
        uint256 randomA;
        uint256 randomB;
    }

    uint256 public constant MAX_TICKETS_PER_RANGE = 1000;
    uint16 public constant VRF_REQUEST_CONFIRMATIONS = 3;
    uint32 public constant VRF_NUM_WORDS = 2;

    uint256 public immutable s_subscriptionId;
    bytes32 public immutable s_keyHash;
    uint32 public s_callbackGasLimit;

    address public feeRecipient;
    uint256 public protocolFeePercent;

    uint256 internal _nextStakeId;
    uint256 internal _nextRoundId;

    mapping(uint256 => StakeConfig) internal _stakeConfigs;
    mapping(uint256 => bool) internal _stakeDeleted;
    mapping(uint256 => Round) internal _rounds;
    mapping(uint256 => uint256) internal _stakeCurrentRound;
    mapping(uint256 => mapping(address => TicketRange[])) internal _userTickets;
    mapping(uint256 => uint256) internal _vrfRequestToRound;
    mapping(uint256 => mapping(address => bool)) internal _hasRefunded;

    constructor(
        address vrfCoordinator,
        uint256 subscriptionId,
        bytes32 keyHash,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        s_subscriptionId = subscriptionId;
        s_keyHash = keyHash;
        s_callbackGasLimit = callbackGasLimit;
    }
}
