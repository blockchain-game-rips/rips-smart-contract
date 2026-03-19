// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IRips {
    enum RoundStatus {
        Active,
        SoldOut,
        VRFRequested,
        Finalized
    }

    struct Round {
        uint64 stakeId;
        uint40 startTime;
        uint32 ticketsSold;
        RoundStatus status;
        uint256 randomA;
        uint256 randomB;
    }

    struct PrizeTier {
        uint256 prizeCount;
        uint256 minPrize;
        uint256 maxPrize;
    }

    struct StakeConfig {
        PrizeTier[] prizeDistribution;
        uint256 ticketCap;
        uint256 duration;
        uint256 ticketCost;
    }

    struct TicketRange {
        uint96 start;
        uint96 count;
        bool claimed;
    }

    error FeeTooHigh();
    error TicketCapNotPowerOfTwo();
    error EmptyPrizeDistribution();
    error InvalidPrizeRange();
    error PrizeCountMismatch();
    error PrizePoolMismatch();
    error StakeNotExist();
    error ZeroTickets();
    error IncorrectPayment();
    error RoundNotSoldOut();
    error RoundNotFinalized();
    error InvalidStartIndex();
    error FeeTransferFailed();
    error PrizeTransferFailed();
    error RoundNotExpired();
    error AlreadyRefunded();
    error NoTicketsToRefund();
    error RefundFailed();
    error RoundNotExist();

    event StakeCreated(uint256 indexed stakeId, uint256 ticketCap, uint256 ticketCost);
    event StakeDeleted(uint256 indexed stakeId);
    event RoundCreated(uint256 indexed roundId, uint256 indexed stakeId, uint256 startTime);
    event TicketsPurchased(
        uint256 indexed roundId, address indexed buyer, uint256 startTicket, uint256 count
    );
    event RandomnessRequested(uint256 indexed roundId, uint256 vrfRequestId);
    event RoundFinalized(uint256 indexed roundId, uint256 randomA, uint256 randomB);
    event PrizesClaimed(uint256 indexed roundId, address indexed claimer, uint256 amount);
    event RefundIssued(uint256 indexed roundId, address indexed user, uint256 amount);
    event ProtocolFeeUpdated(uint256 newFeePercent);
    event FeeRecipientUpdated(address newRecipient);
    event CallbackGasLimitUpdated(uint32 newLimit);

    function buyTickets(uint256 stakeId, uint256 ticketCount, address recipient) external payable;

    function claimPrizes(uint256 roundId, uint256 startIndex, uint256 maxRanges, address recipient)
        external;

    function refund(uint256 roundId, address recipient) external;

    function createStake(StakeConfig calldata config) external returns (uint256 stakeId);

    function deleteStake(uint256 stakeId) external;

    function requestRandomness(uint256 roundId) external returns (uint256 requestId);

    function getUserTickets(uint256 roundId, address user)
        external
        view
        returns (TicketRange[] memory);
}
