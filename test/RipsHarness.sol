// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../src/Rips.sol";
import "../src/modules/RipsMath.sol";

contract RipsHarness is Rips {
    constructor(
        address vrfCoordinator,
        uint256 vrfSubscriptionId,
        bytes32 vrfKeyHash,
        uint32 callbackGasLimit,
        address initialOwner,
        uint256 initialFeePercent
    )
        Rips(
            vrfCoordinator,
            vrfSubscriptionId,
            vrfKeyHash,
            callbackGasLimit,
            initialOwner,
            initialFeePercent
        )
    {}

    function exposed_isPowerOfTwo(uint256 n) external pure returns (bool) {
        return RipsMath.isPowerOfTwo(n);
    }

    function exposed_deriveCoprimeA(uint256 randomValue, uint256 n)
        external
        pure
        returns (uint256)
    {
        return RipsMath.deriveCoprimeA(randomValue, n);
    }

    function exposed_calculatePrizeNumber(uint256 ticketNumber, uint256 a, uint256 b, uint256 n)
        external
        pure
        returns (uint256)
    {
        return RipsMath.calculatePrizeNumber(ticketNumber, a, b, n);
    }

    function exposed_calculatePrizeAmount(uint256 prizeNumber, uint256 stakeId)
        external
        view
        returns (uint256)
    {
        return RipsMath.calculatePrizeAmount(prizeNumber, _stakeConfigs[stakeId]);
    }

    function exposed_calculateTotalPrize(
        uint256 ticketNumber,
        uint256 a,
        uint256 b,
        uint256 n,
        uint256 stakeId
    ) external view returns (uint256) {
        return RipsMath.calculateTotalPrize(ticketNumber, a, b, n, _stakeConfigs[stakeId]);
    }
}
