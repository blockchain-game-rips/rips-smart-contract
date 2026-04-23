// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {RipsStorage} from "../common/RipsStorage.sol";
import {RipsUtils} from "../common/RipsUtils.sol";

abstract contract RipsReferral is RipsStorage, RipsUtils {
    uint256 public constant MAX_REFERRAL_TIER_COUNT = 10;
    uint40 public constant REFERRAL_PERIOD = 30 days;

    uint16 public defaultReferralFee;

    mapping(address referrer => ReferrerState) public referrerToReferrerState;
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

        ReferrerState storage referrerStats = referrerToReferrerState[referrer];
        referrerStats.customFeePercent = customFeePercent;

        emit ReferralStatsUpdated(referrerStats);
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

        ReferrerState storage referrerStats = _resolveReferrerState(referrer, ticketRevenue);

        uint16 customFeePercent = referrerStats.customFeePercent;
        if (customFeePercent > 0) {
            return (protocolFee * customFeePercent) / FEE_BASE;
        }

        uint16 activeFeePercent = referrerStats.activeFeePercent;
        uint16 effectiveFeePercent =
            activeFeePercent > defaultReferralFee ? activeFeePercent : defaultReferralFee;

        referrerFee = (protocolFee * effectiveFeePercent) / FEE_BASE;
    }

    function _resolveReferrerState(address referrer, uint256 ticketRevenue)
        private
        returns (ReferrerState storage referrerStats)
    {
        referrerStats = referrerToReferrerState[referrer];

        uint40 nowTimestamp = uint40(block.timestamp);

        if (nowTimestamp >= referrerStats.monthStartTimestamp + REFERRAL_PERIOD) {
            uint40 periodsElapsed =
                (nowTimestamp - referrerStats.monthStartTimestamp) / REFERRAL_PERIOD;
            bool isConsecutiveMonth = periodsElapsed == 1;

            uint256 volumeInPrevMonth = isConsecutiveMonth ? referrerStats.currMonthVolume : 0;

            referrerStats.activeFeePercent = _resolveTierFeePercent(volumeInPrevMonth);
            referrerStats.monthStartTimestamp += periodsElapsed * REFERRAL_PERIOD;

            referrerStats.currMonthVolume = ticketRevenue;
        } else {
            referrerStats.currMonthVolume += ticketRevenue;
        }

        emit ReferralStatsUpdated(referrerStats);
    }

    function _resolveTierFeePercent(uint256 volume) private view returns (uint16 feePercent) {
        for (uint256 i = referralTiers.length; i > 0; i--) {
            if (volume >= referralTiers[i - 1].minVolume) {
                return referralTiers[i - 1].feePercent;
            }
        }
    }
}
