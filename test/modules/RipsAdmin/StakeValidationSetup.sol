// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract StakeValidationSetup is RipsTestBase {
    function validConfig() internal pure returns (IRips.Config memory) {
        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: uint64(DEFAULT_TICKET_CAP),
            minPrize: uint128(DEFAULT_TICKET_COST),
            maxPrize: uint128(DEFAULT_TICKET_COST)
        });

        return IRips.Config({
            currency: address(0),
            tiers: tiers,
            ticketCap: DEFAULT_TICKET_CAP,
            duration: DEFAULT_DURATION,
            ticketCost: DEFAULT_TICKET_COST,
            feePercent: DEFAULT_FEE_PERCENT
        });
    }

    function configWithNonPowerOfTwoTicketCap() internal pure returns (IRips.Config memory) {
        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: 3,
            minPrize: uint128(DEFAULT_TICKET_COST),
            maxPrize: uint128(DEFAULT_TICKET_COST)
        });

        return IRips.Config({
            currency: address(0),
            tiers: tiers,
            ticketCap: 3,
            duration: DEFAULT_DURATION,
            ticketCost: DEFAULT_TICKET_COST,
            feePercent: DEFAULT_FEE_PERCENT
        });
    }

    function configWithEmptyTiers() internal pure returns (IRips.Config memory) {
        return IRips.Config({
            currency: address(0),
            tiers: new IRips.PrizeTier[](0),
            ticketCap: DEFAULT_TICKET_CAP,
            duration: DEFAULT_DURATION,
            ticketCost: DEFAULT_TICKET_COST,
            feePercent: DEFAULT_FEE_PERCENT
        });
    }

    function configWithMinPrizeGreaterThanMaxPrize() internal pure returns (IRips.Config memory) {
        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: uint64(DEFAULT_TICKET_CAP), minPrize: 2 ether, maxPrize: 1 ether
        });

        return IRips.Config({
            currency: address(0),
            tiers: tiers,
            ticketCap: DEFAULT_TICKET_CAP,
            duration: DEFAULT_DURATION,
            ticketCost: DEFAULT_TICKET_COST,
            feePercent: DEFAULT_FEE_PERCENT
        });
    }

    function configWithPrizeCountMismatch() internal pure returns (IRips.Config memory) {
        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: uint64(DEFAULT_TICKET_CAP - 1),
            minPrize: uint128(DEFAULT_TICKET_COST),
            maxPrize: uint128(DEFAULT_TICKET_COST)
        });

        return IRips.Config({
            currency: address(0),
            tiers: tiers,
            ticketCap: DEFAULT_TICKET_CAP,
            duration: DEFAULT_DURATION,
            ticketCost: DEFAULT_TICKET_COST,
            feePercent: DEFAULT_FEE_PERCENT
        });
    }

    function configWithPrizePoolMismatch() internal pure returns (IRips.Config memory) {
        uint256 wrongPrize = DEFAULT_TICKET_COST + 1;

        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: uint64(DEFAULT_TICKET_CAP),
            minPrize: uint128(wrongPrize),
            maxPrize: uint128(wrongPrize)
        });

        return IRips.Config({
            currency: address(0),
            tiers: tiers,
            ticketCap: DEFAULT_TICKET_CAP,
            duration: DEFAULT_DURATION,
            ticketCost: DEFAULT_TICKET_COST,
            feePercent: DEFAULT_FEE_PERCENT
        });
    }

    function configWithFeeTooHigh() internal pure returns (IRips.Config memory config) {
        config = validConfig();
        config.feePercent = 10001;
    }
}
