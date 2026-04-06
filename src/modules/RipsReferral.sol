// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RipsStorage} from "../common/RipsStorage.sol";
import {RipsUtils} from "../common/RipsUtils.sol";

abstract contract RipsReferral is RipsStorage, RipsUtils {
    uint256 public constant MAX_REFERRAL_TIER_COUNT = 10;
    uint40 public constant REFERRAL_PERIOD = 30 days;

    uint16 public defaultReferralFee;

    mapping(address referrer => ReferrerStats) public referrerToReferrerStats;
    ReferralTier[] public referralTiers;

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

        referrerToReferrerStats[referrer].customFeePercent = customFeePercent;

        emit ReferrerCustomFeeSet(referrer, customFeePercent);
    }

    function setReferralTiers(ReferralTier[] calldata tiers) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (tiers.length > MAX_REFERRAL_TIER_COUNT) revert ReferralTierCountExceeded();

        for (uint256 i = 1; i < tiers.length; i++) {
            if (tiers[i].minVolume <= tiers[i - 1].minVolume) revert ReferralTiersNotSorted();
        }

        delete referralTiers;

        for (uint256 i = 0; i < tiers.length; i++) {
            referralTiers.push(tiers[i]);
        }

        emit ReferralTiersUpdated(tiers);
    }

    function _collectReferrerFee(address referrer, uint256 protocolFee, uint256 ticketRevenue)
        internal
        returns (uint256 referrerFee)
    {
        if (referrer == address(0)) return 0;

        ReferrerStats storage referrerStats = _resolveReferrerStats(referrer, ticketRevenue);

        if (referrerStats.customFeePercent > 0) {
            return (protocolFee * referrerStats.customFeePercent) / FEE_BASE;
        }

        uint16 activeFeePercent = referrerStats.activeFeePercent;
        uint16 effectiveFeePercent =
            activeFeePercent > defaultReferralFee ? activeFeePercent : defaultReferralFee;

        referrerFee = (protocolFee * effectiveFeePercent) / FEE_BASE;
    }

    function _resolveReferrerStats(address referrer, uint256 ticketRevenue)
        private
        returns (ReferrerStats storage referrerStats)
    {
        referrerStats = referrerToReferrerStats[referrer];

        uint40 nowTimestamp = uint40(block.timestamp);

        if (nowTimestamp >= referrerStats.monthStartTimestamp + REFERRAL_PERIOD) {
            bool isConsecutiveMonth =
                nowTimestamp < referrerStats.monthStartTimestamp + 2 * REFERRAL_PERIOD;

            uint256 volumeInPrevMonth = isConsecutiveMonth ? referrerStats.currMonthVolume : 0;

            referrerStats.activeFeePercent = _resolveTierFeePercent(volumeInPrevMonth);
            referrerStats.monthStartTimestamp += REFERRAL_PERIOD;

            referrerStats.currMonthVolume = ticketRevenue;
        } else {
            referrerStats.currMonthVolume += ticketRevenue;
        }
    }

    function _resolveTierFeePercent(uint256 volume) private view returns (uint16 feePercent) {
        for (uint256 i = referralTiers.length; i > 0; i--) {
            if (volume >= referralTiers[i - 1].minVolume) {
                return referralTiers[i - 1].feePercent;
            }
        }
    }
}
