// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../common/RipsUtils.sol";
import "../libraries/RipsMath.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFMigratableConsumerV2Plus.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

//TODO: refund if too much time has passed since vrf requested
abstract contract RipsVrf is RipsUtils, IVRFMigratableConsumerV2Plus {
    //TODO: move error to interface
    error OnlyCoordinatorCanFulfill(address have, address want);

    uint32 public constant VRF_NUM_WORDS = 1;

    uint16 public vrfRequestConfirmations;

    IVRFCoordinatorV2Plus public s_vrfCoordinator;
    uint256 public vrfSubscriptionId;
    bytes32 public vrfKeyHash;
    uint32 private s_callbackGasLimit;

    mapping(uint256 requestId => uint256 roundId) internal _vrfRequestToRound;

    constructor(
        address vrfCoordinator,
        uint256 vrfSubscriptionId_,
        bytes32 vrfKeyHash_,
        uint32 callbackGasLimit
    ) {
        if (vrfCoordinator == address(0)) revert ZeroAddress();
        if (vrfSubscriptionId_ == 0) revert ZeroSubscriptionId();

        s_vrfCoordinator = IVRFCoordinatorV2Plus(vrfCoordinator);
        vrfSubscriptionId = vrfSubscriptionId_;
        vrfKeyHash = vrfKeyHash_;
        s_callbackGasLimit = callbackGasLimit;
        vrfRequestConfirmations = 0;
    }

    function setCoordinator(address vrfCoordinator) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (vrfCoordinator == address(0)) revert ZeroAddress();
        s_vrfCoordinator = IVRFCoordinatorV2Plus(vrfCoordinator);
        emit CoordinatorSet(vrfCoordinator);
    }

    function updateVrfSubscriptionId(uint256 newSubscriptionId)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (newSubscriptionId == 0) revert ZeroSubscriptionId();
        vrfSubscriptionId = newSubscriptionId;
        emit VrfSubscriptionIdUpdated(newSubscriptionId);
    }

    function updateVrfKeyHash(bytes32 newKeyHash) public onlyRole(DEFAULT_ADMIN_ROLE) {
        vrfKeyHash = newKeyHash;
        emit VrfKeyHashUpdated(newKeyHash);
    }

    function updateVrfRequestConfirmations(uint16 newConfirmations)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        vrfRequestConfirmations = newConfirmations;
        emit VrfRequestConfirmationsUpdated(newConfirmations);
    }

    function updateCallbackGasLimit(uint32 newLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        //TODO: consider case when admin set insufficient gas limit and callback is reverted
        s_callbackGasLimit = newLimit;
        emit CallbackGasLimitUpdated(newLimit);
    }

    //TODO: if there is insufficient LINK balance on the subscription or chainlink stops to work account funds will be frozen
    function requestRandomness(uint256 roundId) external returns (uint256 requestId) {
        Round storage round = roundIdToRound[roundId];
        if (round.stakeId == 0) revert RoundNotExist();

        if (round.status != RoundStatus.Active) revert VrfAlreadyRequested();

        Config storage config = configIdToConfig[round.configId];
        if (!_isSoldOut(round, config)) revert RoundNotSoldOut();

        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: vrfKeyHash,
                subId: vrfSubscriptionId,
                requestConfirmations: vrfRequestConfirmations,
                callbackGasLimit: s_callbackGasLimit,
                numWords: VRF_NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        round.status = RoundStatus.VRFRequested;
        _vrfRequestToRound[requestId] = roundId;
        _roundIdToRequestTimestamp[roundId] = block.timestamp;

        emit RandomnessRequested(roundId, requestId);
    }

    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external {
        if (msg.sender != address(s_vrfCoordinator)) {
            revert OnlyCoordinatorCanFulfill(msg.sender, address(s_vrfCoordinator));
        }

        fulfillRandomWords(requestId, randomWords);
    }

    //TODO: add validation tests
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal {
        uint256 roundId = _vrfRequestToRound[requestId];

        if (roundId == 0) revert RoundNotExist();

        Round storage round = roundIdToRound[roundId];

        if (round.status != RoundStatus.VRFRequested) revert InvalidRoundStatus();
        if (_isVrfRequestExpired(roundId)) revert RoundExpired();

        Config storage config = configIdToConfig[round.configId];

        uint64 n = config.ticketCap;
        uint256 randomWord = randomWords[0];
        round.randomA = RipsMath.deriveCoprimeA(randomWord, n);
        round.randomB = uint64(uint256(keccak256(abi.encode(randomWord))) % n);
        round.status = RoundStatus.Finalized;

        emit RoundFinalized(roundId, round.randomA, round.randomB);
    }
}
