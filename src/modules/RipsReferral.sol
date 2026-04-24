// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RipsStorage} from "../common/RipsStorage.sol";
import {RipsUtils} from "../common/RipsUtils.sol";

abstract contract RipsReferral is RipsStorage, RipsUtils {
    uint256 public constant MAX_REFERRAL_TIER_COUNT = 10;
    uint40 public constant REFERRAL_PERIOD = 30 days;

    uint16 public defaultReferralFee;

    mapping(address referrer => uint16 customFeePercent) public referrerCustomFee;
    mapping(address referrer => mapping(address currency => ReferrerState)) public
        referrerToReferrerState;
    mapping(address currency => ReferralTier[]) internal _referralTiers;

    function setDefaultReferralFee(uint16 newDefaultReferralFee)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (newDefaultReferralFee > FEE_BASE) revert FeeTooHigh();

        defaultReferralFee = newDefaultReferralFee;

        emit DefaultReferralFeeUpdated(newDefaultReferralFee);
    }

    function setReferrerCustomFee(address referrer, uint16 customFeePercent)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (referrer == address(0)) revert ZeroAddress();
        if (customFeePercent > FEE_BASE) revert FeeTooHigh();

        referrerCustomFee[referrer] = customFeePercent;

        emit ReferrerCustomFeeUpdated(referrer, customFeePercent);
    }

    function setReferralTiers(address currency, ReferralTier[] calldata tiers)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        if (tiers.length > MAX_REFERRAL_TIER_COUNT) revert ReferralTierCountExceeded();

        for (uint256 i = 1; i < tiers.length; i++) {
            if (tiers[i].minVolume <= tiers[i - 1].minVolume) revert ReferralTiersNotSorted();
        }

        delete _referralTiers[currency];

        for (uint256 i = 0; i < tiers.length; i++) {
            _referralTiers[currency].push(tiers[i]);
        }

        emit ReferralTiersUpdated(currency, tiers);
    }

    function getReferralTiers(address currency) external view returns (ReferralTier[] memory) {
        return _referralTiers[currency];
    }

    function _collectReferrerFee(
        address referrer,
        address currency,
        uint256 protocolFee,
        uint256 ticketRevenue
    ) internal returns (uint256 referrerFee) {
        if (referrer == address(0)) return 0;

        ReferrerState storage referrerStats =
            _resolveReferrerState(referrer, currency, ticketRevenue);

        uint16 customFeePercent = referrerCustomFee[referrer];
        if (customFeePercent > 0) {
            return (protocolFee * customFeePercent) / FEE_BASE;
        }

        uint16 activeFeePercent = referrerStats.activeFeePercent;
        uint16 effectiveFeePercent =
            activeFeePercent > defaultReferralFee ? activeFeePercent : defaultReferralFee;

        referrerFee = (protocolFee * effectiveFeePercent) / FEE_BASE;
    }

    function _resolveReferrerState(address referrer, address currency, uint256 ticketRevenue)
        private
        returns (ReferrerState storage referrerStats)
    {
        referrerStats = referrerToReferrerState[referrer][currency];

        uint40 nowTimestamp = uint40(block.timestamp);

        if (nowTimestamp >= referrerStats.monthStartTimestamp + REFERRAL_PERIOD) {
            uint40 periodsElapsed =
                (nowTimestamp - referrerStats.monthStartTimestamp) / REFERRAL_PERIOD;
            bool isConsecutiveMonth = periodsElapsed == 1;

            uint256 volumeInPrevMonth = isConsecutiveMonth ? referrerStats.currMonthVolume : 0;

            referrerStats.activeFeePercent = _resolveTierFeePercent(currency, volumeInPrevMonth);
            referrerStats.monthStartTimestamp += periodsElapsed * REFERRAL_PERIOD;

            referrerStats.currMonthVolume = ticketRevenue;
        } else {
            referrerStats.currMonthVolume += ticketRevenue;
        }

        emit ReferralStateUpdated(referrer, currency, referrerStats);
    }

    function _resolveTierFeePercent(address currency, uint256 volume)
        private
        view
        returns (uint16 feePercent)
    {
        ReferralTier[] storage tiers = _referralTiers[currency];

        for (uint256 i = tiers.length; i > 0; i--) {
            if (volume >= tiers[i - 1].minVolume) {
                return tiers[i - 1].feePercent;
            }
        }
    }
}
