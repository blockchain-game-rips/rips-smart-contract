// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RipsAdmin} from "./modules/RipsAdmin.sol";
import {RipsFees} from "./modules/RipsFees.sol";
import {RipsReferral} from "./modules/RipsReferral.sol";
import {RipsVrf} from "./modules/RipsVrf.sol";
import {RipsBuyTickets} from "./modules/RipsBuyTickets.sol";
import {RipsClaimPrizes} from "./modules/RipsClaimPrizes.sol";
import {RipsRefund} from "./modules/RipsRefund.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Rips is
    RipsAdmin,
    RipsFees,
    RipsReferral,
    RipsVrf,
    RipsBuyTickets,
    RipsClaimPrizes,
    RipsRefund,
    ReentrancyGuard
{
    constructor(
        address vrfCoordinator,
        uint256 vrfSubscriptionId,
        bytes32 vrfKeyHash,
        uint32 callbackGasLimit
    )
        RipsFees(msg.sender)
        RipsVrf(vrfCoordinator, vrfSubscriptionId, vrfKeyHash, callbackGasLimit)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function getUserTickets(uint256 roundId, address user)
        external
        view
        returns (TicketRange[] memory)
    {
        return _userTickets[roundId][user];
    }
}
