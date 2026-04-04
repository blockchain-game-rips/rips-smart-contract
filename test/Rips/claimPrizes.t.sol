// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";

contract Rips_ClaimPrizes is RipsTestBase {
    uint256 private constant START_INDEX = 0;
    uint256 private constant MAX_RANGES = 10;
    uint16 private constant FEE_PERCENT = 500;
    uint256 private constant FEE_PRIZE_PER_TICKET = 0.95 ether;

    uint256 private stakeId;
    uint256 private roundId;

    function setUp() public override {
        super.setUp();

        vrfCoordinator.fundSubscription(vrfSubscriptionId, 100 ether);

        stakeId = _createDefaultStake();

        vm.deal(user, 100 ether);
        vm.prank(user);
        rips.buyTickets{value: DEFAULT_TICKET_CAP * DEFAULT_TICKET_COST}(
            stakeId, DEFAULT_TICKET_CAP, user
        );

        roundId = rips.stakeIdToCurrentRoundId(stakeId);
    }

    function _finalizeRound() private {
        uint256 vrfRequestId = rips.requestRandomness(roundId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));
    }

    function _totalPrize() private pure returns (uint256) {
        return DEFAULT_TICKET_CAP * DEFAULT_TICKET_COST;
    }

    function _feePrizePool() private pure returns (uint256) {
        return DEFAULT_TICKET_CAP * FEE_PRIZE_PER_TICKET;
    }

    function _protocolFee() private pure returns (uint256) {
        return DEFAULT_TICKET_CAP * DEFAULT_TICKET_COST * FEE_PERCENT / 10_000;
    }

    function _createFeeNativeStake() private returns (uint256 feeRoundId) {
        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: uint64(DEFAULT_TICKET_CAP),
            minPrize: uint128(FEE_PRIZE_PER_TICKET),
            maxPrize: uint128(FEE_PRIZE_PER_TICKET)
        });

        vm.prank(owner);
        uint256 feeStakeId = rips.createStake(
            IRips.Config({
                currency: address(0),
                tiers: tiers,
                ticketCap: DEFAULT_TICKET_CAP,
                duration: DEFAULT_DURATION,
                ticketCost: DEFAULT_TICKET_COST,
                feePercent: FEE_PERCENT
            })
        );

        vm.prank(user);
        rips.buyTickets{value: DEFAULT_TICKET_CAP * DEFAULT_TICKET_COST}(
            feeStakeId, DEFAULT_TICKET_CAP, user
        );

        feeRoundId = rips.stakeIdToCurrentRoundId(feeStakeId);
        uint256 vrfRequestId = rips.requestRandomness(feeRoundId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));
    }

    function test_RevertWhen_TheRoundIsNotFinalized() external {
        vm.prank(user);
        vm.expectRevert(IRips.RoundNotFulfilled.selector);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user, referrer);
    }

    function test_RevertWhen_RecipientIsZeroAddress() external {
        _finalizeRound();

        vm.prank(user);
        vm.expectRevert();
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, address(0), referrer);
    }

    function test_RevertWhen_StartIndexIsOutOfBounds() external {
        _finalizeRound();

        IRips.TicketRange[] memory ranges = rips.getUserTickets(roundId, user);
        uint256 outOfBoundsIndex = ranges.length;

        vm.prank(user);
        vm.expectRevert(IRips.InvalidStartIndex.selector);
        rips.claimPrizes(roundId, outOfBoundsIndex, MAX_RANGES, user, referrer);
    }

    function test_WhenAllRangesInScopeAreAlreadyClaimed() external {
        _finalizeRound();

        vm.prank(user);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user, referrer);

        uint256 balanceBefore = user.balance;

        vm.prank(user);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user, referrer);

        assertEq(user.balance, balanceBefore);
    }

    modifier whenThereAreUnclaimedRanges() {
        _finalizeRound();
        _;
    }

    function test_WhenThereAreUnclaimedRanges_MarksRangesAsClaimed()
        external
        whenThereAreUnclaimedRanges
    {
        vm.prank(user);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user, referrer);

        IRips.TicketRange[] memory ranges = rips.getUserTickets(roundId, user);
        for (uint256 i = 0; i < ranges.length; i++) {
            assertTrue(ranges[i].claimed);
        }
    }

    function test_WhenThereAreUnclaimedRanges_CalculatesCorrectPrizes()
        external
        whenThereAreUnclaimedRanges
    {
        uint256 balanceBefore = user.balance;

        vm.prank(user);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user, referrer);

        assertEq(user.balance, balanceBefore + _totalPrize());
    }

    function test_RevertWhen_CallerIsNotTheRecipientAndHasNeitherAdminNorOperatorRole()
        external
        whenThereAreUnclaimedRanges
    {
        address caller = makeAddr("caller");

        vm.prank(caller);
        vm.expectRevert(IRips.NotRecipientOrOwner.selector);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user, referrer);
    }

    function test_WhenCallerHasAdminRoleAndRecipientIsADifferentAddress()
        external
        whenThereAreUnclaimedRanges
    {
        uint256 recipientBalanceBefore = user.balance;
        uint256 ownerBalanceBefore = owner.balance;

        vm.prank(owner);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user, referrer);

        assertEq(user.balance, recipientBalanceBefore + _totalPrize());
        assertEq(owner.balance, ownerBalanceBefore);
    }

    function test_WhenCallerHasOperatorRoleAndRecipientIsADifferentAddress()
        external
        whenThereAreUnclaimedRanges
    {
        vm.startPrank(owner);
        rips.grantRole(rips.OPERATOR_ROLE(), operator);
        vm.stopPrank();

        uint256 recipientBalanceBefore = user.balance;
        uint256 operatorBalanceBefore = operator.balance;

        vm.prank(operator);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user, referrer);

        assertEq(user.balance, recipientBalanceBefore + _totalPrize());
        //TODO: unnecessary assert, check Rips smart contract balance
        assertEq(operator.balance, operatorBalanceBefore);
    }

    modifier givenTheStakeCurrencyIsNative() {
        _;
    }

    function test_WhenProtocolFeeIsZero()
        external
        whenThereAreUnclaimedRanges
        givenTheStakeCurrencyIsNative
    {
        uint256 balanceBefore = user.balance;

        vm.expectEmit();
        emit IRips.PrizesClaimed(roundId, user, referrer, DEFAULT_TICKET_CAP, _totalPrize());

        vm.prank(user);
        rips.claimPrizes(roundId, START_INDEX, MAX_RANGES, user, referrer);

        assertEq(user.balance, balanceBefore + _totalPrize());
    }

    function test_WhenProtocolFeeIsGreaterThanZero()
        external
        whenThereAreUnclaimedRanges
        givenTheStakeCurrencyIsNative
    {
        uint256 feeRoundId = _createFeeNativeStake();

        uint256 userBalanceBefore = user.balance;

        vm.expectEmit();
        emit IRips.PrizesClaimed(feeRoundId, user, referrer, DEFAULT_TICKET_CAP, _feePrizePool());

        vm.prank(user);
        rips.claimPrizes(feeRoundId, START_INDEX, MAX_RANGES, user, referrer);

        assertEq(user.balance, userBalanceBefore + _feePrizePool());
        assertEq(rips.protocolFeeAccrued(address(0)), _protocolFee());
    }

    function test_WhenProtocolFeeIsZero_GivenTheStakeCurrencyIsAnERC20Token() external {
        _mintAndApprove(user, DEFAULT_TICKET_CAP * DEFAULT_TICKET_COST);

        uint256 erc20StakeId = _createDefaultERC20Stake();

        vm.prank(user);
        rips.buyTickets(erc20StakeId, DEFAULT_TICKET_CAP, user);

        uint256 erc20RoundId = rips.stakeIdToCurrentRoundId(erc20StakeId);
        uint256 vrfRequestId = rips.requestRandomness(erc20RoundId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));

        uint256 balanceBefore = erc20.balanceOf(user);

        vm.expectEmit();
        emit IRips.PrizesClaimed(erc20RoundId, user, referrer, DEFAULT_TICKET_CAP, _totalPrize());

        vm.prank(user);
        rips.claimPrizes(erc20RoundId, START_INDEX, MAX_RANGES, user, referrer);

        assertEq(erc20.balanceOf(user), balanceBefore + _totalPrize());
    }

    function test_WhenProtocolFeeIsGreaterThanZero_GivenTheStakeCurrencyIsAnERC20Token() external {
        _mintAndApprove(user, DEFAULT_TICKET_CAP * DEFAULT_TICKET_COST);

        IRips.PrizeTier[] memory tiers = new IRips.PrizeTier[](1);
        tiers[0] = IRips.PrizeTier({
            prizeCount: uint64(DEFAULT_TICKET_CAP),
            minPrize: uint128(FEE_PRIZE_PER_TICKET),
            maxPrize: uint128(FEE_PRIZE_PER_TICKET)
        });

        vm.prank(owner);
        uint256 feeStakeId = rips.createStake(
            IRips.Config({
                currency: address(erc20),
                tiers: tiers,
                ticketCap: DEFAULT_TICKET_CAP,
                duration: DEFAULT_DURATION,
                ticketCost: DEFAULT_TICKET_COST,
                feePercent: FEE_PERCENT
            })
        );

        vm.prank(user);
        rips.buyTickets(feeStakeId, DEFAULT_TICKET_CAP, user);

        uint256 feeRoundId = rips.stakeIdToCurrentRoundId(feeStakeId);
        uint256 vrfRequestId = rips.requestRandomness(feeRoundId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));

        uint256 userBalanceBefore = erc20.balanceOf(user);

        vm.expectEmit();
        emit IRips.PrizesClaimed(feeRoundId, user, referrer, DEFAULT_TICKET_CAP, _feePrizePool());

        vm.prank(user);
        rips.claimPrizes(feeRoundId, START_INDEX, MAX_RANGES, user, referrer);

        assertEq(erc20.balanceOf(user), userBalanceBefore + _feePrizePool());
        assertEq(rips.protocolFeeAccrued(address(erc20)), _protocolFee());
    }
}
