// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RipsUtils} from "../common/RipsUtils.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

abstract contract RipsEnterRip is RipsUtils, Pausable {
    using SafeERC20 for IERC20;

    uint64 public constant MAX_ENTRIES_PER_RANGE = 1000;

    function enterRip(uint64 stakeId, uint64 entryCount, address recipient)
        external
        payable
        whenNotPaused
    {
        if (recipient == address(0)) revert ZeroAddress();
        if (entryCount == 0) revert ZeroEntries();

        (uint256 ripId, Rip storage rip, Config storage config) = _resolveRipAndConfig(stakeId);

        uint64 toBuy = _getEntriesToBuy(rip, config, entryCount);

        _purchaseEntries(ripId, rip, recipient, toBuy);

        uint256 nativeExcess = _receivePayment(config, toBuy, msg.sender);

        if (nativeExcess > 0) {
            _sendNative(recipient, nativeExcess);
        }
    }

    function _resolveRipAndConfig(uint64 stakeId)
        private
        returns (uint256 ripId, Rip storage rip, Config storage config)
    {
        ripId = stakeIdToCurrentRipId[stakeId];

        if (ripId != 0) {
            rip = ripIdToRip[ripId];
            config = configIdToConfig[rip.configId];

            // rip is filling
            if (!_isExpired(rip, config) && !_isSoldOut(rip, config)) {
                return (ripId, rip, config);
            }
        }

        if (isStakeDeleted[stakeId]) revert StakeNotExist();

        // stake is fresh, no rip yet
        if (ripId == 0) {
            uint64 configId = stakeIdToCurrentConfigId[stakeId];

            // entryCap is guaranteed non-zero by isPowerOfTwo validation
            if (configIdToConfig[configId].entryCap == 0) revert StakeNotExist();
        }

        // rip is sold out or expired
        return _createRip(stakeId);
    }

    function _createRip(uint64 stakeId)
        private
        returns (uint256 ripId, Rip storage rip, Config storage config)
    {
        ripId = _nextRipId++;
        rip = ripIdToRip[ripId];

        uint64 configId = stakeIdToCurrentConfigId[stakeId];
        config = configIdToConfig[configId];

        rip.stakeId = uint64(stakeId);
        rip.configId = uint64(configId);
        rip.startTime = uint40(block.timestamp);
        rip.vrfRequestStatus = VrfRequestStatus.NotRequested;

        stakeIdToCurrentRipId[stakeId] = ripId;

        emit RipCreated(ripId, stakeId, configId);
    }

    function _getEntriesToBuy(Rip storage rip, Config storage config, uint64 entryCount)
        private
        view
        returns (uint64)
    {
        uint64 available = config.entryCap - rip.entriesSold;

        return entryCount > available ? available : entryCount;
    }

    function _purchaseEntries(
        uint256 ripId,
        Rip storage rip,
        address recipient,
        uint64 entriesToBuy
    ) private {
        uint64 startEntry = rip.entriesSold;

        rip.entriesSold += entriesToBuy;

        _storeEntryRanges(ripId, recipient, startEntry, entriesToBuy);

        emit RipEntered(ripId, recipient, entriesToBuy, startEntry);
    }

    function _storeEntryRanges(uint256 ripId, address buyer, uint64 startEntry, uint64 entryCount)
        private
    {
        EntryRange[] storage ranges = userEntries[ripId][buyer];
        uint64 remaining = entryCount;
        uint64 currentStart = startEntry;

        while (remaining > 0) {
            uint64 rangeSize = remaining > MAX_ENTRIES_PER_RANGE ? MAX_ENTRIES_PER_RANGE : remaining;

            ranges.push(
                EntryRange({start: uint64(currentStart), count: uint64(rangeSize), claimed: false})
            );
            currentStart += rangeSize;
            remaining -= rangeSize;
        }

        userEntryCount[ripId][buyer] += entryCount;
    }

    function _receivePayment(Config storage config, uint256 toBuy, address from)
        private
        returns (uint256 nativeExcess)
    {
        uint256 requiredPayment = toBuy * config.entryPrice;
        address currency = config.currency;

        if (_isNative(currency)) {
            if (msg.value < requiredPayment) revert IncorrectPayment();

            nativeExcess = msg.value - requiredPayment;
        } else {
            if (msg.value != 0) revert EthSentForERC20();

            IERC20(currency).safeTransferFrom(from, address(this), requiredPayment);
        }
    }
}
