// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../common/RipsUtils.sol";
import "../libraries/RipsMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFMigratableConsumerV2Plus.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

//TODO: refund if too much time has passed since vrf requested
abstract contract RipsVrf is RipsUtils, AccessControl, IVRFMigratableConsumerV2Plus {
    error OnlyCoordinatorCanFulfill(address have, address want);

    uint16 public constant VRF_REQUEST_CONFIRMATIONS = 3;
    uint32 public constant VRF_NUM_WORDS = 1;

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
                requestConfirmations: VRF_REQUEST_CONFIRMATIONS,
                callbackGasLimit: s_callbackGasLimit,
                numWords: VRF_NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        round.status = RoundStatus.VRFRequested;
        _vrfRequestToRound[requestId] = roundId;

        emit RandomnessRequested(roundId, requestId);
    }

    function rawFulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) external {
        if (msg.sender != address(s_vrfCoordinator)) {
            revert OnlyCoordinatorCanFulfill(msg.sender, address(s_vrfCoordinator));
        }

        fulfillRandomWords(requestId, randomWords);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal {
        uint256 roundId = _vrfRequestToRound[requestId];
        Round storage round = roundIdToRound[roundId];
        Config storage config = configIdToConfig[round.configId];

        uint64 n = config.ticketCap;
        uint256 randomWord = randomWords[0];
        round.randomA = RipsMath.deriveCoprimeA(randomWord, n);
        round.randomB = uint64(uint256(keccak256(abi.encode(randomWord))) % n);
        round.status = RoundStatus.Finalized;

        emit RoundFinalized(roundId, round.randomA, round.randomB);
    }
}
