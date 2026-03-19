// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

//TODO: rethink about test and function itself
contract Rips_CreateStake is RipsTestBase {
    function _validTiers() private pure returns (IRips.PrizeTier[] memory tiers) {
        tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: uint64(DEFAULT_TICKET_CAP),
            minPrize: uint128(DEFAULT_TICKET_COST),
            maxPrize: uint128(DEFAULT_TICKET_COST)
        });
    }

    function _validConfig() private pure returns (IRips.StakeConfig memory) {
        return IRips.StakeConfig({
            prizeDistribution: _validTiers(),
            ticketCap: DEFAULT_TICKET_CAP,
            duration: DEFAULT_DURATION,
            ticketCost: DEFAULT_TICKET_COST
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
        tiers[0] = IRips.PrizeTier({prizeCount: 3, minPrize: uint128(DEFAULT_TICKET_COST), maxPrize: uint128(DEFAULT_TICKET_COST)});

        vm.expectRevert(IRips.TicketCapNotPowerOfTwo.selector);
        rips.createStake(
            IRips.StakeConfig({
                prizeDistribution: tiers, ticketCap: 3, duration: DEFAULT_DURATION, ticketCost: DEFAULT_TICKET_COST
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
            IRips.StakeConfig({
                prizeDistribution: emptyTiers,
                ticketCap: DEFAULT_TICKET_CAP,
                duration: DEFAULT_DURATION,
                ticketCost: DEFAULT_TICKET_COST
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
        tiers[0] = IRips.PrizeTier({prizeCount: uint64(DEFAULT_TICKET_CAP), minPrize: 2 ether, maxPrize: 1 ether});

        vm.expectRevert(IRips.InvalidPrizeRange.selector);
        rips.createStake(
            IRips.StakeConfig({
                prizeDistribution: tiers,
                ticketCap: DEFAULT_TICKET_CAP,
                duration: DEFAULT_DURATION,
                ticketCost: DEFAULT_TICKET_COST
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
            prizeCount: uint64(DEFAULT_TICKET_CAP - 1), minPrize: uint128(DEFAULT_TICKET_COST), maxPrize: uint128(DEFAULT_TICKET_COST)
        });

        vm.expectRevert(IRips.PrizeCountMismatch.selector);
        rips.createStake(
            IRips.StakeConfig({
                prizeDistribution: tiers,
                ticketCap: DEFAULT_TICKET_CAP,
                duration: DEFAULT_DURATION,
                ticketCost: DEFAULT_TICKET_COST
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
        tiers[0] =
            IRips.PrizeTier({prizeCount: uint64(DEFAULT_TICKET_CAP), minPrize: uint128(wrongPrize), maxPrize: uint128(wrongPrize)});

        vm.expectRevert(IRips.PrizePoolMismatch.selector);
        rips.createStake(
            IRips.StakeConfig({
                prizeDistribution: tiers,
                ticketCap: DEFAULT_TICKET_CAP,
                duration: DEFAULT_DURATION,
                ticketCost: DEFAULT_TICKET_COST
            })
        );
    }

    function test_WhenTotalPrizePoolEqualsTicketCapTimesTicketCost()
        external
        whenTheCallerIsTheOwner
        whenTicketCapIsAPowerOfTwo
        whenPrizeDistributionIsNotEmpty
        whenAllTiersHaveValidPrizeRanges
        whenTotalPrizeCountEqualsTicketCap
    {
        uint256 expectedStakeId = rips.exposed_nextStakeId();

        vm.expectEmit();
        emit IRips.RoundCreated(rips.exposed_nextRoundId(), expectedStakeId, block.timestamp);

        vm.expectEmit();
        emit IRips.StakeCreated(expectedStakeId, DEFAULT_TICKET_CAP, DEFAULT_TICKET_COST);

        uint256 stakeId = rips.createStake(_validConfig());

        assertEq(stakeId, expectedStakeId);
        assertEq(rips.exposed_nextStakeId(), expectedStakeId + 1);
        assertEq(rips.exposed_stakeConfig(stakeId).ticketCap, DEFAULT_TICKET_CAP);
        assertEq(rips.exposed_stakeConfig(stakeId).ticketCost, DEFAULT_TICKET_COST);
        assertNotEq(rips.exposed_stakeToActiveRound(stakeId), 0);
    }
}
