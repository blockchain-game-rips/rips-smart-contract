// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IRips {
    enum VrfRequestStatus {
        NotRequested,
        Requested,
        Fulfilled
    }

    struct Round {
        uint64 stakeId;
        uint64 configId;
        uint40 startTime;
        uint32 ticketsSold;
        VrfRequestStatus vrfRequestStatus;
        uint64 randomA;
        uint64 randomB;
    }

    struct PrizeTier {
        uint64 prizeCount;
        uint128 minPrize;
        uint128 maxPrize;
    }

    struct Config {
        PrizeTier[] tiers;
        address currency;
        uint64 ticketCap;
        uint32 duration;
        uint256 ticketCost;
        uint16 feePercent;
    }

    struct TicketRange {
        uint96 start;
        uint96 count;
        bool claimed;
    }

    struct ReferrerStats {
        uint128 currMonthVolume;
        uint16 activeFeePercent;
        uint16 customFeePercent;
        uint32 currentMonth;
    }

    struct ReferralTier {
        uint128 minVolume;
        uint16 feePercent;
    }

    error ZeroAddress();
    error EthSentForERC20();
    error FeeTooHigh();
    error NothingToWithdraw();
    error ReferrerFrozen();
    error TicketCapNotPowerOfTwo();
    error InvalidTierCount();
    error InvalidPrizeRange();
    error TiersNotSortedByCount();
    error PrizeCountMismatch();
    error PrizePoolMismatch();
    error StakeNotExist();
    error ZeroTickets();
    error IncorrectPayment();
    error RoundNotSoldOut();
    error RoundNotFulfilled();
    error InvalidVrfRequestStatus();
    error RoundExpired();
    error InvalidStartIndex();
    error TransferFailed();
    error RoundNotExpired();
    error AlreadyRefunded();
    error NoTicketsToRefund();
    error RoundNotExist();
    error ReferralTiersEmpty();
    error ReferralTiersNotSorted();
    error ReferralTierCountExceeded();
    error NotRecipientOrOwner();
    error VrfAlreadyRequested();
    error ZeroSubscriptionId();
    error InvalidRequestId();

    event StakeCreated(uint256 indexed stakeId);
    event StakeUpdated(uint256 indexed stakeId);
    event StakeDeleted(uint256 indexed stakeId);
    event RoundCreated(uint256 indexed roundId, uint256 indexed stakeId);
    event TicketsPurchased(
        uint256 indexed roundId, address indexed user, uint256 ticketCount, uint256 startTicketIndex
    );
    event RandomnessRequested(uint256 indexed roundId, uint256 vrfRequestId);
    event RoundFinalized(uint256 indexed roundId, uint256 randomA, uint256 randomB);
    event PrizesClaimed(
        uint256 indexed roundId,
        address indexed user,
        address referrer,
        uint256 ticketCount,
        uint256 prizeAmount
    );
    event RefundIssued(uint256 indexed roundId, address indexed user, uint256 ticketCount);
    event FeeRecipientUpdated(address newRecipient);
    event ProtocolFeeWithdrawn(address indexed recipient, address indexed currency, uint256 amount);
    event ReferrerFeeWithdrawn(address indexed referrer, address indexed currency, uint256 amount);
    event ReferrerFeeSeized(address indexed referrer, address indexed currency, uint256 amount);
    event ReferrerFreezeUpdated(address indexed referrer, bool frozen);
    event CallbackGasLimitUpdated(uint32 newLimit);
    event VrfRequestConfirmationsUpdated(uint16 newConfirmations);
    event VrfSubscriptionIdUpdated(uint256 newSubscriptionId);
    event VrfKeyHashUpdated(bytes32 newKeyHash);
    event ReferralTiersUpdated(ReferralTier[] tiers);
    event DefaultReferralFeeUpdated(uint16 newDefaultReferralFee);
    event ReferrerCustomFeeSet(address indexed referrer, uint16 customFeePercent);
    event ReferralFeePaid(uint256 indexed roundId, address indexed referrer, uint256 amount);

    function buyTickets(uint256 stakeId, uint256 ticketCount, address recipient) external payable;

    function claimPrizes(
        uint256 roundId,
        uint256 startIndex,
        uint256 maxRanges,
        address recipient,
        address referrer
    ) external;

    function refund(uint256 roundId, address recipient) external;

    function createStake(Config calldata config) external returns (uint256 stakeId);

    function updateStake(uint256 stakeId, Config calldata config) external;

    function deleteStake(uint256 stakeId) external;

    function requestRandomness(uint256 roundId) external returns (uint256 requestId);

    function getUserTickets(uint256 roundId, address user)
        external
        view
        returns (TicketRange[] memory);

    function setReferralTiers(ReferralTier[] calldata tiers) external;

    function setDefaultReferralFee(uint16 newDefaultReferralFee) external;

    function setReferrerCustomFee(address referrer, uint16 customFeePercent) external;

    function withdrawProtocolFee(address currency) external;

    function withdrawReferrerFee(address referrer, address currency) external;

    function setReferrerFrozen(address referrer, bool frozen) external;

    function seizeReferrerFee(address referrer, address currency) external;
}
