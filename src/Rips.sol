// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RipsAdmin} from "./modules/RipsAdmin.sol";
import {RipsFees} from "./modules/RipsFees.sol";
import {RipsReferral} from "./modules/RipsReferral.sol";
import {RipsVrf} from "./modules/RipsVRF.sol";
import {RipsEnterRip} from "./modules/RipsEnterRip.sol";
import {RipsClaimPayout} from "./modules/RipsClaimPayout.sol";
import {RipsRefund} from "./modules/RipsRefund.sol";

contract Rips is
    RipsAdmin,
    RipsFees,
    RipsReferral,
    RipsVrf,
    RipsEnterRip,
    RipsClaimPayout,
    RipsRefund
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

    function getUserEntries(uint256 ripId, address user)
        external
        view
        returns (EntryRange[] memory)
    {
        return userEntries[ripId][user];
    }
}
