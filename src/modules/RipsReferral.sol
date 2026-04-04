// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../common/RipsStorage.sol";
import "../common/RipsUtils.sol";

abstract contract RipsReferral is RipsStorage, RipsUtils {
    uint256 public constant MAX_REFERRAL_TIER_COUNT = 10;

    uint16 public defaultReferralFee;

    mapping(address referrer => ReferrerStats stats) public referrerToReferrerStats;
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

        ReferrerStats storage stats = referrerToReferrerStats[referrer];

        if (stats.customFeePercent > 0) {
            return (protocolFee * stats.customFeePercent) / FEE_BASE;
        }

        if (referralTiers.length == 0 && defaultReferralFee == 0) return 0;

        uint32 currentMonth = uint32(block.timestamp / 30 days);

        if (stats.currentMonth < currentMonth) {
            uint16 prevNextFeePercent = stats.nextFeePercent;

            stats.activeFeePercent =
                (currentMonth == stats.currentMonth + 1) ? prevNextFeePercent : 0;
            stats.nextFeePercent = 0;
            stats.currMonthVolume = 0;
            stats.currentMonth = currentMonth;
        }

        stats.currMonthVolume += uint128(ticketRevenue);

        uint16 newNextFeePercent = _resolveTierFeePercent(stats.currMonthVolume);

        if (newNextFeePercent != stats.nextFeePercent) {
            stats.nextFeePercent = newNextFeePercent;
            emit ReferrerStatsUpdated(referrer, stats.activeFeePercent, newNextFeePercent);
        }

        uint16 effectiveFeePercent = stats.activeFeePercent > defaultReferralFee
            ? stats.activeFeePercent
            : defaultReferralFee;

        referrerFee = (protocolFee * effectiveFeePercent) / FEE_BASE;
    }

    function _resolveTierFeePercent(uint128 volume) private view returns (uint16 feePercent) {
        for (uint256 i = referralTiers.length; i > 0; i--) {
            if (volume >= referralTiers[i - 1].minVolume) {
                return referralTiers[i - 1].feePercent;
            }
        }
    }
}
