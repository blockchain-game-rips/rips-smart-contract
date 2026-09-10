// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RipsStorage} from "./RipsStorage.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

abstract contract RipsUtils is RipsStorage, AccessControl, ReentrancyGuard {
    uint256 public constant FEE_BASE = 10000;

    // how long a pending VRF request is honoured before its rip falls back to refunds
    uint256 public constant VRF_REQUEST_EXPIRY = 7 weeks;

    using SafeERC20 for IERC20;

    /// @notice Whether a rip can still be entered, is waiting on randomness, or has
    /// fallen through to refunds. `vrfRequestStatus` stays the source of truth once
    /// randomness is in play: claiming and the VRF callback read it directly, because
    /// they need the exact request phase rather than these coarser states.
    /// @dev Entry and refund ask this instead of re-deriving the answer from
    /// timestamps and entry counts, so their conditions cannot drift apart.
    function _ripState(uint256 ripId) internal view returns (RipState) {
        Rip storage rip = ripIdToRip[ripId];
        Config storage config = configIdToConfig[rip.configId];

        // Cancellation outranks everything: cancelRip only accepts a Filling rip, so a
        // cancelled rip never had randomness in play and its entries can only refund.
        if (rip.isCancelled) return RipState.Refundable;

        // Sold out outranks expiry: a full rip pays out however long it took to fill,
        // and requestRandomness only accepts a sold-out rip, so every requested or
        // fulfilled rip reaches its state through this branch.
        if (_isSoldOut(rip, config)) {
            if (rip.vrfRequestStatus == VrfRequestStatus.Fulfilled) return RipState.Payable;

            if (rip.vrfRequestStatus == VrfRequestStatus.NotRequested) return RipState.AwaitingRandomness;

            return _isVrfRequestExpired(ripId) ? RipState.Refundable : RipState.AwaitingRandomness;
        }

        if (_isExpired(rip, config)) return RipState.Refundable;

        return RipState.Filling;
    }

    function _isExpired(Rip storage rip, Config storage config) internal view returns (bool) {
        return block.timestamp > rip.startTime + config.duration;
    }

    function _isSoldOut(Rip storage rip, Config storage config) internal view returns (bool) {
        return rip.entriesSold == config.entryCap;
    }

    function _isNative(address currency) internal pure returns (bool) {
        return currency == address(0);
    }

    function _transfer(address currency, address to, uint256 amount) internal {
        if (_isNative(currency)) {
            _sendNative(to, amount);
        } else {
            IERC20(currency).safeTransfer(to, amount);
        }
    }

    function _sendNative(address to, uint256 amount) internal {
        (bool success,) = to.call{value: amount}("");

        if (!success) revert TransferFailed();
    }

    function _isPrivileged(address account) internal view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account) || hasRole(OPERATOR_ROLE, account);
    }

    function _isVrfRequestExpired(uint256 ripId) internal view returns (bool) {
        uint256 requestTimestamp = _ripIdToRequestTimestamp[ripId];

        if (requestTimestamp == 0) return false;

        if (block.timestamp > requestTimestamp + VRF_REQUEST_EXPIRY) {
            return true;
        }

        return false;
    }
}
