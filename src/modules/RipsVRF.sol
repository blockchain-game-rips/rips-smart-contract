// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RipsUtils} from "../common/RipsUtils.sol";
import {RipsMath} from "../libraries/RipsMath.sol";
import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
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

    mapping(uint256 requestId => uint256 ripId) internal _vrfRequestToRip;

    constructor(address vrfCoordinator_, uint256 vrfSubscriptionId_, bytes32 vrfKeyHash_, uint32 callbackGasLimit_) {
        if (vrfCoordinator_ == address(0)) revert ZeroAddress();
        if (vrfSubscriptionId_ == 0) revert ZeroSubscriptionId();

        vrfCoordinator = IVRFCoordinatorV2Plus(vrfCoordinator_);
        vrfSubscriptionId = vrfSubscriptionId_;
        vrfKeyHash = vrfKeyHash_;
        callbackGasLimit = callbackGasLimit_;
        // Base coordinator accepts 0; other chains may require a nonzero minimum.
        vrfRequestConfirmations = 0;
        _grantRole(VRF_COORDINATOR_ROLE, vrfCoordinator_);
    }

    function setCoordinator(address newVrfCoordinator) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newVrfCoordinator == address(0)) revert ZeroAddress();

        _revokeRole(VRF_COORDINATOR_ROLE, address(vrfCoordinator));
        _grantRole(VRF_COORDINATOR_ROLE, newVrfCoordinator);

        vrfCoordinator = IVRFCoordinatorV2Plus(newVrfCoordinator);

        emit CoordinatorSet(newVrfCoordinator);
    }

    function updateVrfSubscriptionId(uint256 newSubscriptionId) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newSubscriptionId == 0) revert ZeroSubscriptionId();
        vrfSubscriptionId = newSubscriptionId;
        emit VrfSubscriptionIdUpdated(newSubscriptionId);
    }

    function updateVrfKeyHash(bytes32 newKeyHash) public onlyRole(DEFAULT_ADMIN_ROLE) {
        vrfKeyHash = newKeyHash;
        emit VrfKeyHashUpdated(newKeyHash);
    }

    function updateVrfRequestConfirmations(uint16 newConfirmations) external onlyRole(DEFAULT_ADMIN_ROLE) {
        vrfRequestConfirmations = newConfirmations;
        emit VrfRequestConfirmationsUpdated(newConfirmations);
    }

    function updateCallbackGasLimit(uint32 newLimit) external onlyRole(DEFAULT_ADMIN_ROLE) {
        callbackGasLimit = newLimit;
        emit CallbackGasLimitUpdated(newLimit);
    }

    function requestRandomness(uint256 ripId) external returns (uint256 requestId) {
        Rip storage rip = ripIdToRip[ripId];
        if (rip.presetId == 0) revert RipNotExist();

        // Phase before lifecycle: losing the race to request is a normal outcome and
        // callers must be able to tell it apart from a rip that is not ready at all.
        if (rip.vrfRequestStatus != VrfRequestStatus.NotRequested) revert VrfAlreadyRequested();

        if (_ripState(ripId) != RipState.AwaitingRandomness) revert RipNotSoldOut();

        requestId = vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: vrfKeyHash,
                subId: vrfSubscriptionId,
                requestConfirmations: vrfRequestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: VRF_NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );

        if (requestId == 0) revert InvalidRequestId();
        if (_vrfRequestToRip[requestId] != 0) revert InvalidRequestId();

        rip.vrfRequestStatus = VrfRequestStatus.Requested;
        _vrfRequestToRip[requestId] = ripId;
        _ripIdToRequestTimestamp[ripId] = block.timestamp;

        emit RandomnessRequested(ripId, requestId);
    }

    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords)
        external
        onlyRole(VRF_COORDINATOR_ROLE)
    {
        fulfillRandomWords(requestId, randomWords);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal {
        uint256 ripId = _vrfRequestToRip[requestId];

        if (ripId == 0) revert RipNotExist();

        Rip storage rip = ripIdToRip[ripId];

        if (rip.vrfRequestStatus != VrfRequestStatus.Requested) revert InvalidVrfRequestStatus();
        if (_isVrfRequestExpired(ripId)) revert RipExpired();

        Config storage config = configIdToConfig[rip.configId];

        uint64 n = config.entryCap;
        uint256 randomWord = randomWords[0];
        rip.randomA = RipsMath.deriveCoprimeA(randomWord, n);
        rip.randomB = uint64(uint256(keccak256(abi.encode(randomWord))) % n);
        rip.vrfRequestStatus = VrfRequestStatus.Fulfilled;

        emit RandomnessFulfilled(ripId, rip.randomA, rip.randomB);
    }
}
