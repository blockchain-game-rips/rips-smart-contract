// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./modules/RipsVrf.sol";
import "./modules/RipsBuyTickets.sol";
import "./modules/RipsClaimPrizes.sol";
import "./modules/RipsRefund.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Rips is RipsVrf, RipsBuyTickets, RipsClaimPrizes, RipsRefund, ReentrancyGuard {
    constructor(
        address vrfCoordinator,
        uint256 vrfSubscriptionId,
        bytes32 vrfKeyHash,
        uint32 callbackGasLimit
    ) RipsVrf(vrfCoordinator, vrfSubscriptionId, vrfKeyHash, callbackGasLimit) {
        setFeeRecipient(msg.sender);
    }

    function getUserTickets(uint256 roundId, address user)
        external
        view
        returns (TicketRange[] memory)
    {
        return _userTickets[roundId][user];
    }
}
