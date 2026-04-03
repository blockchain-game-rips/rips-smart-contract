// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

// TODO: make the three flatten
contract Rips_CreateStake is RipsTestBase {
    function _validTiers() private pure returns (IRips.PrizeTier[] memory tiers) {
        tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: uint64(DEFAULT_TICKET_CAP),
            minPrize: uint128(DEFAULT_TICKET_COST),
            maxPrize: uint128(DEFAULT_TICKET_COST)
        });
    }

    function _validConfig() private pure returns (IRips.Config memory) {
        return IRips.Config({
            currency: address(0),
            prizeDistribution: _validTiers(),
            ticketCap: DEFAULT_TICKET_CAP,
            duration: DEFAULT_DURATION,
            ticketCost: DEFAULT_TICKET_COST,
            feePercent: DEFAULT_FEE_PERCENT
        });
    }

    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        vm.prank(user);
        vm.expectRevert();
        rips.createStake(_validConfig());
    }

    modifier whenTheCallerIsTheOwner() {
        vm.startPrank(owner);
        _;
        vm.stopPrank();
    }

    function test_RevertWhen_TicketCapIsNotAPowerOfTwo() external whenTheCallerIsTheOwner {
        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: 3,
            minPrize: uint128(DEFAULT_TICKET_COST),
            maxPrize: uint128(DEFAULT_TICKET_COST)
        });

        vm.expectRevert(IRips.TicketCapNotPowerOfTwo.selector);
        rips.createStake(
            IRips.Config({
                currency: address(0),
                prizeDistribution: tiers,
                ticketCap: 3,
                duration: DEFAULT_DURATION,
                ticketCost: DEFAULT_TICKET_COST,
                feePercent: DEFAULT_FEE_PERCENT
            })
        );
    }

    modifier whenTicketCapIsAPowerOfTwo() {
        _;
    }

    function test_RevertWhen_PrizeDistributionIsEmpty()
        external
        whenTheCallerIsTheOwner
        whenTicketCapIsAPowerOfTwo
    {
        IRips.PrizeTier[] memory emptyTiers = new IRips.PrizeTier[](0);

        vm.expectRevert(IRips.EmptyPrizeDistribution.selector);
        rips.createStake(
            IRips.Config({
                currency: address(0),
                prizeDistribution: emptyTiers,
                ticketCap: DEFAULT_TICKET_CAP,
                duration: DEFAULT_DURATION,
                ticketCost: DEFAULT_TICKET_COST,
                feePercent: DEFAULT_FEE_PERCENT
            })
        );
    }

    modifier whenPrizeDistributionIsNotEmpty() {
        _;
    }

    function test_RevertWhen_ATierHasMinPrizeGreaterThanMaxPrize()
        external
        whenTheCallerIsTheOwner
        whenTicketCapIsAPowerOfTwo
        whenPrizeDistributionIsNotEmpty
    {
        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: uint64(DEFAULT_TICKET_CAP), minPrize: 2 ether, maxPrize: 1 ether
        });

        vm.expectRevert(IRips.InvalidPrizeRange.selector);
        rips.createStake(
            IRips.Config({
                currency: address(0),
                prizeDistribution: tiers,
                ticketCap: DEFAULT_TICKET_CAP,
                duration: DEFAULT_DURATION,
                ticketCost: DEFAULT_TICKET_COST,
                feePercent: DEFAULT_FEE_PERCENT
            })
        );
    }

    modifier whenAllTiersHaveValidPrizeRanges() {
        _;
    }

    function test_RevertWhen_TotalPrizeCountDoesNotEqualTicketCap()
        external
        whenTheCallerIsTheOwner
        whenTicketCapIsAPowerOfTwo
        whenPrizeDistributionIsNotEmpty
        whenAllTiersHaveValidPrizeRanges
    {
        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: uint64(DEFAULT_TICKET_CAP - 1),
            minPrize: uint128(DEFAULT_TICKET_COST),
            maxPrize: uint128(DEFAULT_TICKET_COST)
        });

        vm.expectRevert(IRips.PrizeCountMismatch.selector);
        rips.createStake(
            IRips.Config({
                currency: address(0),
                prizeDistribution: tiers,
                ticketCap: DEFAULT_TICKET_CAP,
                duration: DEFAULT_DURATION,
                ticketCost: DEFAULT_TICKET_COST,
                feePercent: DEFAULT_FEE_PERCENT
            })
        );
    }

    modifier whenTotalPrizeCountEqualsTicketCap() {
        _;
    }

    function test_RevertWhen_TotalPrizePoolDoesNotEqualTicketCapTimesTicketCost()
        external
        whenTheCallerIsTheOwner
        whenTicketCapIsAPowerOfTwo
        whenPrizeDistributionIsNotEmpty
        whenAllTiersHaveValidPrizeRanges
        whenTotalPrizeCountEqualsTicketCap
    {
        uint256 wrongPrize = DEFAULT_TICKET_COST + 1;
        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: uint64(DEFAULT_TICKET_CAP),
            minPrize: uint128(wrongPrize),
            maxPrize: uint128(wrongPrize)
        });

        vm.expectRevert(IRips.PrizePoolMismatch.selector);
        rips.createStake(
            IRips.Config({
                currency: address(0),
                prizeDistribution: tiers,
                ticketCap: DEFAULT_TICKET_CAP,
                duration: DEFAULT_DURATION,
                ticketCost: DEFAULT_TICKET_COST,
                feePercent: DEFAULT_FEE_PERCENT
            })
        );
    }

    modifier whenTotalPrizePoolEqualsTicketCapTimesTicketCost() {
        _;
    }

    function test_RevertWhen_FeePercentExceeds10000()
        external
        whenTheCallerIsTheOwner
        whenTicketCapIsAPowerOfTwo
        whenPrizeDistributionIsNotEmpty
        whenAllTiersHaveValidPrizeRanges
        whenTotalPrizeCountEqualsTicketCap
        whenTotalPrizePoolEqualsTicketCapTimesTicketCost
    {
        IRips.Config memory config = _validConfig();
        config.feePercent = 10001;

        vm.expectRevert(IRips.FeeTooHigh.selector);
        rips.createStake(config);
    }

    function test_WhenFeePercentIsAtMost10000()
        external
        whenTheCallerIsTheOwner
        whenTicketCapIsAPowerOfTwo
        whenPrizeDistributionIsNotEmpty
        whenAllTiersHaveValidPrizeRanges
        whenTotalPrizeCountEqualsTicketCap
        whenTotalPrizePoolEqualsTicketCapTimesTicketCost
    {
        uint256 expectedStakeId = rips.exposed_nextStakeId();

        vm.expectEmit();
        emit IRips.StakeCreated(expectedStakeId);

        uint256 stakeId = rips.createStake(_validConfig());

        assertEq(stakeId, expectedStakeId);
        assertEq(rips.exposed_nextStakeId(), expectedStakeId + 1);

        uint256 configId = rips.stakeIdToCurrentConfigId(stakeId);
        assertNotEq(configId, 0);

        IRips.Config memory config = rips.exposed_config(configId);
        assertEq(config.ticketCap, DEFAULT_TICKET_CAP);
        assertEq(config.ticketCost, DEFAULT_TICKET_COST);
        assertEq(config.feePercent, DEFAULT_FEE_PERCENT);
    }
}
