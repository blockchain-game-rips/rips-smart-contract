// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RipsStorage} from "./RipsStorage.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract RipsUtils is RipsStorage, AccessControl {
    uint256 public constant FEE_BASE = 10000;

    using SafeERC20 for IERC20;

    function _isExpired(Round storage round, Config storage config) internal view returns (bool) {
        return block.timestamp > round.startTime + config.duration;
    }

    function _isSoldOut(Round storage round, Config storage config) internal view returns (bool) {
        return round.ticketsSold == config.ticketCap;
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

    function _isVrfRequestExpired(uint256 roundId) internal view returns (bool) {
        uint256 requestTimestamp = _roundIdToRequestTimestamp[roundId];

        if (requestTimestamp == 0) return false;

        if (block.timestamp > requestTimestamp + 7 weeks) {
            return true;
        }

        return false;
    }
}
