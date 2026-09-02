// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RipsUtils} from "../common/RipsUtils.sol";

abstract contract RipsFees is RipsUtils {
    address public feeRecipient;

    mapping(address referrer => bool frozen) public isReferrerFrozen;

    constructor(address initialFeeRecipient) {
        if (initialFeeRecipient == address(0)) revert ZeroAddress();

        feeRecipient = initialFeeRecipient;

        emit FeeRecipientUpdated(initialFeeRecipient);
    }

    function setFeeRecipient(address newRecipient) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newRecipient == address(0)) revert ZeroAddress();

        feeRecipient = newRecipient;

        emit FeeRecipientUpdated(newRecipient);
    }

    function withdrawProtocolFee(address currency) external nonReentrant {
        if (!_isPrivileged(msg.sender)) {
            revert AccessControlUnauthorizedAccount(msg.sender, OPERATOR_ROLE);
        }
        uint256 amount = protocolFeeAccrued[currency];
        if (amount == 0) revert NothingToWithdraw();

        protocolFeeAccrued[currency] = 0;

        _transfer(currency, feeRecipient, amount);

        emit ProtocolFeeWithdrawn(feeRecipient, currency, amount);
    }

    function setReferrerFrozen(address referrer, bool frozen) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (referrer == address(0)) revert ZeroAddress();

        isReferrerFrozen[referrer] = frozen;

        emit ReferrerFreezeUpdated(referrer, frozen);
    }

    function seizeReferrerFee(address referrer, address currency) external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        if (referrer == address(0)) revert ZeroAddress();

        uint256 amount = referrerFeeAccrued[referrer][currency];
        if (amount == 0) revert NothingToWithdraw();

        referrerFeeAccrued[referrer][currency] = 0;

        _transfer(currency, feeRecipient, amount);

        emit ReferrerFeeSeized(referrer, currency, amount);
    }

    function withdrawReferrerFee(address referrer, address currency) external nonReentrant {
        if (referrer == address(0)) revert ZeroAddress();
        if (isReferrerFrozen[referrer]) revert ReferrerFrozen();

        uint256 amount = referrerFeeAccrued[referrer][currency];
        if (amount == 0) revert NothingToWithdraw();

        referrerFeeAccrued[referrer][currency] = 0;

        _transfer(currency, referrer, amount);

        emit ReferrerFeeWithdrawn(referrer, currency, amount);
    }
}
