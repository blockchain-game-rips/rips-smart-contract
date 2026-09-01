// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract PresetValidationSetup is RipsTestBase {
    function validConfig() internal pure returns (IRips.Config memory) {
        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](1);
        tiers[0] = IRips.PayoutTier({
            payoutCount: uint64(DEFAULT_ENTRY_CAP),
            minPayout: uint128(DEFAULT_ENTRY_PRICE),
            maxPayout: uint128(DEFAULT_ENTRY_PRICE)
        });

        return IRips.Config({
            currency: address(0),
            tiers: tiers,
            entryCap: DEFAULT_ENTRY_CAP,
            duration: DEFAULT_DURATION,
            entryPrice: DEFAULT_ENTRY_PRICE,
            feeBps: DEFAULT_FEE_PERCENT
        });
    }

    function configWithNonPowerOfTwoEntryCap() internal pure returns (IRips.Config memory) {
        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](1);
        tiers[0] = IRips.PayoutTier({
            payoutCount: 3,
            minPayout: uint128(DEFAULT_ENTRY_PRICE),
            maxPayout: uint128(DEFAULT_ENTRY_PRICE)
        });

        return IRips.Config({
            currency: address(0),
            tiers: tiers,
            entryCap: 3,
            duration: DEFAULT_DURATION,
            entryPrice: DEFAULT_ENTRY_PRICE,
            feeBps: DEFAULT_FEE_PERCENT
        });
    }

    function configWithInvalidTierCount() internal pure returns (IRips.Config memory) {
        return IRips.Config({
            currency: address(0),
            tiers: new IRips.PayoutTier[](0),
            entryCap: DEFAULT_ENTRY_CAP,
            duration: DEFAULT_DURATION,
            entryPrice: DEFAULT_ENTRY_PRICE,
            feeBps: DEFAULT_FEE_PERCENT
        });
    }

    function configWithMinPayoutGreaterThanMaxPayout() internal pure returns (IRips.Config memory) {
        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](1);
        tiers[0] = IRips.PayoutTier({
            payoutCount: uint64(DEFAULT_ENTRY_CAP), minPayout: 2 ether, maxPayout: 1 ether
        });

        return IRips.Config({
            currency: address(0),
            tiers: tiers,
            entryCap: DEFAULT_ENTRY_CAP,
            duration: DEFAULT_DURATION,
            entryPrice: DEFAULT_ENTRY_PRICE,
            feeBps: DEFAULT_FEE_PERCENT
        });
    }

    function configWithPayoutCountMismatch() internal pure returns (IRips.Config memory) {
        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](1);
        tiers[0] = IRips.PayoutTier({
            payoutCount: uint64(DEFAULT_ENTRY_CAP - 1),
            minPayout: uint128(DEFAULT_ENTRY_PRICE),
            maxPayout: uint128(DEFAULT_ENTRY_PRICE)
        });

        return IRips.Config({
            currency: address(0),
            tiers: tiers,
            entryCap: DEFAULT_ENTRY_CAP,
            duration: DEFAULT_DURATION,
            entryPrice: DEFAULT_ENTRY_PRICE,
            feeBps: DEFAULT_FEE_PERCENT
        });
    }

    function configWithPayoutPoolMismatch() internal pure returns (IRips.Config memory) {
        uint256 wrongPayout = DEFAULT_ENTRY_PRICE + 1;

        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](1);
        tiers[0] = IRips.PayoutTier({
            payoutCount: uint64(DEFAULT_ENTRY_CAP),
            minPayout: uint128(wrongPayout),
            maxPayout: uint128(wrongPayout)
        });

        return IRips.Config({
            currency: address(0),
            tiers: tiers,
            entryCap: DEFAULT_ENTRY_CAP,
            duration: DEFAULT_DURATION,
            entryPrice: DEFAULT_ENTRY_PRICE,
            feeBps: DEFAULT_FEE_PERCENT
        });
    }

    function configWithTierCountExceedsMax() internal view returns (IRips.Config memory) {
        uint256 tierCount = rips.MAX_TIER_COUNT() + 1;

        return IRips.Config({
            currency: address(0),
            tiers: new IRips.PayoutTier[](tierCount),
            entryCap: DEFAULT_ENTRY_CAP,
            duration: DEFAULT_DURATION,
            entryPrice: DEFAULT_ENTRY_PRICE,
            feeBps: DEFAULT_FEE_PERCENT
        });
    }

    function configWithFeeTooHigh() internal pure returns (IRips.Config memory config) {
        config = validConfig();
        config.feeBps = uint16(10001);
    }

    function configWithZeroPayoutCountTier() internal pure returns (IRips.Config memory) {
        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](2);
        tiers[0] = IRips.PayoutTier({
            payoutCount: uint64(DEFAULT_ENTRY_CAP),
            minPayout: uint128(DEFAULT_ENTRY_PRICE),
            maxPayout: uint128(DEFAULT_ENTRY_PRICE)
        });
        tiers[1] = IRips.PayoutTier({payoutCount: 0, minPayout: 0, maxPayout: 0});

        return IRips.Config({
            currency: address(0),
            tiers: tiers,
            entryCap: DEFAULT_ENTRY_CAP,
            duration: DEFAULT_DURATION,
            entryPrice: DEFAULT_ENTRY_PRICE,
            feeBps: DEFAULT_FEE_PERCENT
        });
    }

    function configWithTiersNotSortedByPayoutCount() internal pure returns (IRips.Config memory) {
        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](2);
        tiers[0] = IRips.PayoutTier({
            payoutCount: 1,
            minPayout: uint128(DEFAULT_ENTRY_PRICE * 3),
            maxPayout: uint128(DEFAULT_ENTRY_PRICE * 3)
        });
        tiers[1] = IRips.PayoutTier({
            payoutCount: uint64(DEFAULT_ENTRY_CAP - 1),
            minPayout: uint128(DEFAULT_ENTRY_PRICE),
            maxPayout: uint128(DEFAULT_ENTRY_PRICE)
        });

        return IRips.Config({
            currency: address(0),
            tiers: tiers,
            entryCap: DEFAULT_ENTRY_CAP,
            duration: DEFAULT_DURATION,
            entryPrice: DEFAULT_ENTRY_PRICE,
            feeBps: DEFAULT_FEE_PERCENT
        });
    }
}
