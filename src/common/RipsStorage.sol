// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IRips} from "../interfaces/IRips.sol";

abstract contract RipsStorage is IRips {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    mapping(address currency => uint256 amount) public protocolFeeAccrued;
    mapping(address referrer => mapping(address currency => uint256 amount)) public
        referrerFeeAccrued;

    uint64 internal _nextStakeId = 1;
    uint256 internal _nextRipId = 1;
    uint64 internal _nextConfigId = 1;

    mapping(uint64 configId => Config config) public configIdToConfig;
    mapping(uint64 configId => uint64[] boundaries) public configIdToTierBoundaries;

    mapping(uint256 ripId => Rip rip) public ripIdToRip;

    mapping(uint64 stakeId => uint64 configId) public stakeIdToCurrentConfigId;
    mapping(uint64 stakeId => uint256 ripId) public stakeIdToCurrentRipId;
    mapping(uint64 stakeId => bool deleted) public isStakeDeleted;

    mapping(uint256 ripId => mapping(address buyer => EntryRange[] ranges)) internal userEntries;
    mapping(uint256 ripId => mapping(address buyer => uint64 entryCount)) public userEntryCount;

    mapping(uint256 ripId => uint256 requestTimestamp) internal _ripIdToRequestTimestamp;
}
