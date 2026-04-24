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
        uint64 ticketsSold;
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
        uint64 start;
        uint64 count;
        bool claimed;
    }

    struct ReferrerState {
        uint16 activeFeePercent;
        uint40 monthStartTimestamp;
        uint256 currMonthVolume;
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

    event StakeCreated(uint64 indexed stakeId, uint64 configId);
    event StakeUpdated(uint64 indexed stakeId, uint64 configId);
    event StakeDeleted(uint64 indexed stakeId);

    event RoundCreated(uint256 indexed roundId, uint64 indexed stakeId, uint64 configId);

    event TicketsPurchased(
        uint256 indexed roundId, address indexed user, uint64 ticketCount, uint256 startTicketIndex
    );
    event PrizesClaimed(
        uint256 indexed roundId,
        address indexed user,
        address referrer,
        uint64 ticketCount,
        uint256 prizeAmount
    );
    event RefundIssued(uint256 indexed roundId, address indexed user, uint64 ticketCount);

    event RandomnessRequested(uint256 indexed roundId, uint256 vrfRequestId);
    event RandomnessFulfilled(uint256 indexed roundId, uint256 randomA, uint256 randomB);
    event CallbackGasLimitUpdated(uint32 newLimit);
    event VrfRequestConfirmationsUpdated(uint16 newConfirmations);
    event VrfSubscriptionIdUpdated(uint256 newSubscriptionId);
    event VrfKeyHashUpdated(bytes32 newKeyHash);

    event FeeRecipientUpdated(address newRecipient);
    event ProtocolFeeWithdrawn(address indexed recipient, address indexed currency, uint256 amount);

    event ReferrerFeeWithdrawn(address indexed referrer, address indexed currency, uint256 amount);
    event ReferrerFeeSeized(address indexed referrer, address indexed currency, uint256 amount);
    event ReferrerFreezeUpdated(address indexed referrer, bool frozen);
    event ReferralTiersUpdated(address indexed currency, ReferralTier[] tiers);
    event DefaultReferralFeeUpdated(uint16 newDefaultReferralFee);
    event ReferralFeeAccrued(uint256 indexed roundId, address indexed referrer, uint256 amount);
    event ProtocolFeeAccrued(uint256 indexed roundId, uint256 amount);
    event ReferralStateUpdated(
        address indexed referrer, address indexed currency, ReferrerState referrerState
    );
    event ReferrerCustomFeeUpdated(address indexed referrer, uint16 customFeePercent);

    function buyTickets(uint64 stakeId, uint64 ticketCount, address recipient) external payable;

    function claimPrizes(
        uint256 roundId,
        uint256 startIndex,
        uint256 maxRanges,
        address recipient,
        address referrer
    ) external;

    function refund(uint256 roundId, address recipient) external;

    function createStake(Config calldata config) external returns (uint64 stakeId);

    function updateStake(uint64 stakeId, Config calldata config) external;

    function deleteStake(uint64 stakeId) external;

    function requestRandomness(uint256 roundId) external returns (uint256 requestId);

    function getUserTickets(uint256 roundId, address user)
        external
        view
        returns (TicketRange[] memory);

    function setReferralTiers(address currency, ReferralTier[] calldata tiers) external;

    function setDefaultReferralFee(uint16 newDefaultReferralFee) external;

    function setReferrerCustomFee(address referrer, uint16 customFeePercent) external;

    function withdrawProtocolFee(address currency) external;

    function withdrawReferrerFee(address referrer, address currency) external;

    function setReferrerFrozen(address referrer, bool frozen) external;

    function seizeReferrerFee(address referrer, address currency) external;
}
