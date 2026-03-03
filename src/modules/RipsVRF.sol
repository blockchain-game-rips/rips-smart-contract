// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./RipsAdmin.sol";
import "./RipsMath.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

abstract contract RipsVrf is RipsAdmin {
    uint16 public constant VRF_REQUEST_CONFIRMATIONS = 3;
    uint32 public constant VRF_NUM_WORDS = 2;

    uint256 public immutable s_subscriptionId;
    bytes32 public immutable s_keyHash;
    uint32 private s_callbackGasLimit;

    mapping(uint256 => uint256) internal _vrfRequestToRound;

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

    function updateCallbackGasLimit(uint32 newLimit) external onlyOwner {
        s_callbackGasLimit = newLimit;
        emit CallbackGasLimitUpdated(newLimit);
    }

    function requestRandomness(uint256 roundId) external {
        Round storage round = _rounds[roundId];
        if (round.state != RoundState.AwaitingVRF) revert NotAwaitingVRF();
        if (round.vrfRequestId != 0) revert VRFAlreadyRequested();

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: VRF_REQUEST_CONFIRMATIONS,
                callbackGasLimit: s_callbackGasLimit,
                numWords: VRF_NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        round.vrfRequestId = requestId;
        _vrfRequestToRound[requestId] = roundId;

        emit RandomnessRequested(roundId, requestId);
    }

    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal override {
        uint256 roundId = _vrfRequestToRound[requestId];
        Round storage round = _rounds[roundId];
        StakeConfig storage config = _stakeConfigs[round.stakeId];

        uint256 n = config.ticketCap;
        round.randomA = RipsMath.deriveCoprimeA(randomWords[0], n);
        round.randomB = randomWords[1] % n;
        round.state = RoundState.Finalized;

        emit RoundFinalized(roundId, round.randomA, round.randomB);
    }
}
