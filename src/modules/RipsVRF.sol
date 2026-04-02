// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./RipsAdmin.sol";
import "../libraries/RipsMath.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

//TODO: refund if too much time has passed since vrf requested
abstract contract RipsVrf is RipsAdmin {
    uint16 public constant VRF_REQUEST_CONFIRMATIONS = 3;
    uint32 public constant VRF_NUM_WORDS = 1;

    uint256 public immutable vrfSubscriptionId;
    bytes32 public immutable vrfKeyHash;
    uint32 private s_callbackGasLimit;

    mapping(uint256 requestId => uint256 roundId) internal _vrfRequestToRound;

    constructor(
        address vrfCoordinator,
        uint256 vrfSubscriptionId_,
        bytes32 vrfKeyHash_,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        vrfSubscriptionId = vrfSubscriptionId_;
        vrfKeyHash = vrfKeyHash_;
        s_callbackGasLimit = callbackGasLimit;
    }

    function updateCallbackGasLimit(uint32 newLimit) external onlyOwner {
        //TODO: consider case when admin set insufficient gas limit and callback is reverted
        s_callbackGasLimit = newLimit;
        emit CallbackGasLimitUpdated(newLimit);
    }

    //TODO: if there is insufficient LINK balance on the subscription or chainlink stops to work account funds will be frozen
    function requestRandomness(uint256 roundId) external returns (uint256 requestId) {
        Round storage round = roundIdToRound[roundId];
        // if (round.status != RoundStatus.SoldOut) revert RoundNotSoldOut();//TODO:

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

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords)
        internal
        override
    {
        uint256 roundId = _vrfRequestToRound[requestId];
        Round storage round = roundIdToRound[roundId];
        Config storage config = configIdToConfig[round.stakeId];

        uint256 n = config.ticketCap;
        uint256 randomWord = randomWords[0];
        round.randomA = RipsMath.deriveCoprimeA(randomWord, n);
        round.randomB = uint256(keccak256(abi.encode(randomWord))) % n;
        round.status = RoundStatus.Finalized;

        emit RoundFinalized(roundId, round.randomA, round.randomB);
    }
}
