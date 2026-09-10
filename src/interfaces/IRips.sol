// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IRips {
    enum VrfRequestStatus {
        NotRequested,
        Requested,
        Fulfilled
    }

    /// @notice The lifecycle position of a rip. Exactly one state holds at any time.
    enum RipState {
        Filling,
        AwaitingRandomness,
        Payable,
        Refundable
    }

    struct Rip {
        uint64 presetId;
        uint64 configId;
        uint40 startTime;
        uint64 entriesSold;
        VrfRequestStatus vrfRequestStatus;
        bool isCancelled;
        uint64 randomA;
        uint64 randomB;
    }

    struct PayoutTier {
        uint64 payoutCount;
        uint128 minPayout;
        uint128 maxPayout;
    }

    struct Config {
        PayoutTier[] tiers;
        address currency;
        uint64 entryCap;
        uint32 duration;
        uint256 entryPrice;
        uint16 feeBps;
    }

    struct EntryChunk {
        uint64 start;
        uint64 count;
    }

    struct ReferrerState {
        uint16 activeFeeBps;
        uint40 periodStartTimestamp;
        uint256 periodVolume;
    }

    struct ReferralTier {
        uint128 minVolume;
        uint16 feeBps;
    }

    error ZeroAddress();
    error EthSentForERC20();
    error FeeTooHigh();
    error NothingToWithdraw();
    error ReferrerFrozen();
    error EntryCapNotPowerOfTwo();
    error EntryPriceTooLow();
    error InvalidTierCount();
    error InvalidPayoutRange();
    error TiersNotSortedByPayoutCount();
    error InvalidPayoutCount();
    error PayoutPoolMismatch();
    error PresetNotExist();
    error ZeroEntries();
    error IncorrectPayment();
    error RipNotSoldOut();
    error RipNotFulfilled();
    error InvalidVrfRequestStatus();
    error RipExpired();
    error TransferFailed();
    error RipNotExpired();
    error AlreadyRefunded();
    error NoEntriesToRefund();
    error NothingToClaim();
    error ZeroMaxChunks();
    error RipNotExist();
    error ReferralTiersEmpty();
    error ReferralTiersNotSorted();
    error ReferralTierCountExceeded();
    error NotRecipientOrOwner();
    error VrfAlreadyRequested();
    error ZeroSubscriptionId();
    error InvalidRequestId();
    error RipNotCancellable();

    event PresetCreated(uint64 indexed presetId, uint64 configId);
    event PresetUpdated(uint64 indexed presetId, uint64 configId);
    event PresetDeleted(uint64 indexed presetId);

    event RipCreated(uint256 indexed ripId, uint64 indexed presetId, uint64 configId);
    event RipCancelled(uint256 indexed ripId);

    event RipEntered(uint256 indexed ripId, address indexed user, uint64 entryCount, uint256 startEntryIndex);
    event PayoutClaimed(
        uint256 indexed ripId, address indexed user, address referrer, uint64 entryCount, uint256 payoutAmount
    );
    event RefundIssued(uint256 indexed ripId, address indexed user, uint64 entryCount);

    event RandomnessRequested(uint256 indexed ripId, uint256 vrfRequestId);
    event RandomnessFulfilled(uint256 indexed ripId, uint256 randomA, uint256 randomB);
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
    event DefaultReferralFeeUpdated(uint16 newDefaultReferralFeeBps);
    event ReferralFeeAccrued(uint256 indexed ripId, address indexed referrer, uint256 amount);
    event ProtocolFeeAccrued(uint256 indexed ripId, uint256 amount);
    event ReferralStateUpdated(address indexed referrer, address indexed currency, ReferrerState referrerState);
    event ReferrerCustomFeeUpdated(address indexed referrer, uint16 customFeeBps);

    function enterRip(uint64 presetId, uint64 entryCount, address recipient) external payable;

    function claimPayout(uint256 ripId, uint256 maxChunks, address recipient, address referrer) external;

    function refund(uint256 ripId, address recipient) external;

    function createPreset(Config calldata config) external returns (uint64 presetId);

    function updatePreset(uint64 presetId, Config calldata config) external;

    function deletePreset(uint64 presetId) external;

    function cancelRip(uint256 ripId) external;

    function requestRandomness(uint256 ripId) external returns (uint256 requestId);

    function getUserEntries(uint256 ripId, address user) external view returns (EntryChunk[] memory);

    function setReferralTiers(address currency, ReferralTier[] calldata tiers) external;

    function setDefaultReferralFee(uint16 newDefaultReferralFeeBps) external;

    function setReferrerCustomFee(address referrer, uint16 customFeeBps) external;

    function withdrawProtocolFee(address currency) external;

    function withdrawReferrerFee(address referrer, address currency) external;

    function setReferrerFrozen(address referrer, bool frozen) external;

    function seizeReferrerFee(address referrer, address currency) external;
}
