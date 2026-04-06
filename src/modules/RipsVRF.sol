// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RipsUtils} from "../common/RipsUtils.sol";
import {RipsMath} from "../libraries/RipsMath.sol";
import {
    IVRFCoordinatorV2Plus
} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {
    IVRFMigratableConsumerV2Plus
} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFMigratableConsumerV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

abstract contract RipsVrf is RipsUtils, IVRFMigratableConsumerV2Plus {
    bytes32 public constant VRF_COORDINATOR_ROLE = keccak256("VRF_COORDINATOR_ROLE");

    uint32 public constant VRF_NUM_WORDS = 1;

    uint16 public vrfRequestConfirmations;

    IVRFCoordinatorV2Plus public vrfCoordinator;
    uint256 public vrfSubscriptionId;
    bytes32 public vrfKeyHash;
    uint32 public callbackGasLimit;

    mapping(uint256 requestId => uint256 roundId) internal _vrfRequestToRound;

    constructor(
        address vrfCoordinator_,
        uint256 vrfSubscriptionId_,
        bytes32 vrfKeyHash_,
        uint32 callbackGasLimit_
    ) {
        if (vrfCoordinator_ == address(0)) revert ZeroAddress();
        if (vrfSubscriptionId_ == 0) revert ZeroSubscriptionId();

        vrfCoordinator = IVRFCoordinatorV2Plus(vrfCoordinator_);
        vrfSubscriptionId = vrfSubscriptionId_;
        vrfKeyHash = vrfKeyHash_;
        callbackGasLimit = callbackGasLimit_;
        vrfRequestConfirmations = 0;
        _grantRole(VRF_COORDINATOR_ROLE, vrfCoordinator_);
    }

    function setCoordinator(address newVrfCoordinator)
        external
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (newVrfCoordinator == address(0)) revert ZeroAddress();

        _revokeRole(VRF_COORDINATOR_ROLE, address(newVrfCoordinator));
        _grantRole(VRF_COORDINATOR_ROLE, newVrfCoordinator);

        vrfCoordinator = IVRFCoordinatorV2Plus(newVrfCoordinator);

        emit CoordinatorSet(newVrfCoordinator);
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
        callbackGasLimit = newLimit;
        emit CallbackGasLimitUpdated(newLimit);
    }

    function requestRandomness(uint256 roundId) external returns (uint256 requestId) {
        Round storage round = roundIdToRound[roundId];
        if (round.stakeId == 0) revert RoundNotExist();

        if (round.vrfRequestStatus != VrfRequestStatus.NotRequested) revert VrfAlreadyRequested();

        Config storage config = configIdToConfig[round.configId];
        if (!_isSoldOut(round, config)) revert RoundNotSoldOut();

        requestId = vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: vrfKeyHash,
                subId: vrfSubscriptionId,
                requestConfirmations: vrfRequestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: VRF_NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        if (requestId == 0) revert InvalidRequestId();
        if (_vrfRequestToRound[requestId] != 0) revert InvalidRequestId();

        round.vrfRequestStatus = VrfRequestStatus.Requested;
        _vrfRequestToRound[requestId] = roundId;
        _roundIdToRequestTimestamp[roundId] = block.timestamp;

        emit RandomnessRequested(roundId, requestId);
    }

    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords)
        external
        onlyRole(VRF_COORDINATOR_ROLE)
    {
        fulfillRandomWords(requestId, randomWords);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal {
        uint256 roundId = _vrfRequestToRound[requestId];

        if (roundId == 0) revert RoundNotExist();

        Round storage round = roundIdToRound[roundId];

        if (round.vrfRequestStatus != VrfRequestStatus.Requested) revert InvalidVrfRequestStatus();
        if (_isVrfRequestExpired(roundId)) revert RoundExpired();

        Config storage config = configIdToConfig[round.configId];

        uint64 n = config.ticketCap;
        uint256 randomWord = randomWords[0];
        round.randomA = RipsMath.deriveCoprimeA(randomWord, n);
        round.randomB = uint64(uint256(keccak256(abi.encode(randomWord))) % n);
        round.vrfRequestStatus = VrfRequestStatus.Fulfilled;

        emit RandomnessFulfilled(roundId, round.randomA, round.randomB);
    }
}
