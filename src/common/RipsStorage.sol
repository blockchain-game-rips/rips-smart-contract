// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IRips} from "../interfaces/IRips.sol";

abstract contract RipsStorage is IRips {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    mapping(address currency => uint256 amount) public protocolFeeAccrued;
    mapping(address referrer => mapping(address currency => uint256 amount)) public referrerFeeAccrued;

    uint64 internal _nextPresetId = 1;
    uint256 internal _nextRipId = 1;
    uint64 internal _nextConfigId = 1;

    mapping(uint64 configId => Config config) public configIdToConfig;
    mapping(uint64 configId => uint64[] boundaries) public configIdToTierBoundaries;

    mapping(uint256 ripId => Rip rip) public ripIdToRip;

    mapping(uint64 presetId => uint64 configId) public presetIdToCurrentConfigId;
    mapping(uint64 presetId => uint256 ripId) public presetIdToCurrentRipId;
    mapping(uint64 presetId => bool deleted) public isPresetDeleted;

    mapping(uint256 ripId => mapping(address buyer => EntryChunk[] chunks)) internal userEntryChunks;
    mapping(uint256 ripId => mapping(address buyer => uint64 entryCount)) public userEntryCount;

    mapping(uint256 ripId => uint256 requestTimestamp) internal _ripIdToRequestTimestamp;
}
