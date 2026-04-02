// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../common/RipsStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract RipsReferral is RipsStorage, Ownable {
    uint16 public baseFeePercent;

    mapping(address referrer => ReferrerStats stats) public referrerToReferrerStats;
    ReferralTier[] public referralTiers;

    function setBaseFeePercent(uint16 newBaseFeePercent) external onlyOwner {
        if (newBaseFeePercent > 10000) revert FeeTooHigh();

        baseFeePercent = newBaseFeePercent;

        emit BaseFeePercentUpdated(newBaseFeePercent);
    }

    function setReferrerCustomFee(address referrer, uint16 customFeePercent) external onlyOwner {
        if (referrer == address(0)) revert ZeroAddress();
        if (customFeePercent > 10000) revert FeeTooHigh();

        referrerToReferrerStats[referrer].customFeePercent = customFeePercent;

        emit ReferrerCustomFeeSet(referrer, customFeePercent);
    }

    function setReferralTiers(ReferralTier[] calldata tiers) external onlyOwner {
        if (tiers.length == 0) revert ReferralTiersEmpty();

        for (uint256 i = 1; i < tiers.length; i++) {
            if (tiers[i].minVolume <= tiers[i - 1].minVolume) revert ReferralTiersNotSorted();
        }

        delete referralTiers;

        for (uint256 i = 0; i < tiers.length; i++) {
            referralTiers.push(tiers[i]);
        }

        emit ReferralTiersUpdated(tiers);
    }

    function _collectReferrerFee(address referrer, uint256 protocolFee, uint256 claimVolume)
        internal
        returns (uint256 referrerFee)
    {
        if (referrer == address(0)) return 0;

        ReferrerStats storage stats = referrerToReferrerStats[referrer];

        if (stats.customFeePercent > 0) {
            return (protocolFee * stats.customFeePercent) / 10000;
        }

        if (referralTiers.length == 0 && baseFeePercent == 0) return 0;

        uint32 currentMonth = uint32(block.timestamp / 30 days);

        if (stats.currentMonth < currentMonth) {
            uint16 prevNextFeePercent = stats.nextFeePercent;

            stats.activeFeePercent =
                (currentMonth == stats.currentMonth + 1) ? prevNextFeePercent : 0;
            stats.nextFeePercent = 0;
            stats.currMonthVolume = 0;
            stats.currentMonth = currentMonth;
        }

        stats.currMonthVolume += uint128(claimVolume);

        uint16 newNextFeePercent = _resolveTierFeePercent(stats.currMonthVolume);

        if (newNextFeePercent != stats.nextFeePercent) {
            stats.nextFeePercent = newNextFeePercent;
            emit ReferrerStatsUpdated(referrer, stats.activeFeePercent, newNextFeePercent);
        }

        uint16 effectiveFeePercent =
            stats.activeFeePercent > baseFeePercent ? stats.activeFeePercent : baseFeePercent;

        referrerFee = (protocolFee * effectiveFeePercent) / 10000;
    }

    function _resolveTierFeePercent(uint128 volume) private view returns (uint16 feePercent) {
        for (uint256 i = referralTiers.length; i > 0; i--) {
            if (volume >= referralTiers[i - 1].minVolume) {
                return referralTiers[i - 1].feePercent;
            }
        }
    }
}
