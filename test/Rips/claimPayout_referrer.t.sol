// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";

contract Rips_ClaimPayout_Referrer is RipsTestBase {
    uint256 private constant START_INDEX = 0;
    uint256 private constant MAX_CHUNKS = 10;
    uint16 private constant PROTOCOL_FEE_PERCENT = 500; // 5%
    uint256 private constant DEFAULT_REFERRAL_FEE = 300; // 3%
    uint256 private constant CUSTOM_FEE_PERCENT = 2000; // 20%
    uint256 private constant PAYOUT_PER_ENTRY = 0.95 ether;

    uint64 private presetId;
    uint256 private ripId;

    function setUp() public override {
        super.setUp();

        vrfCoordinator.fundSubscription(vrfSubscriptionId, 100 ether);

        presetId = _createFeePreset();

        vm.deal(user, 100 ether);
        vm.prank(user);
        rips.enterRip{value: DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE}(
            presetId, DEFAULT_ENTRY_CAP, user
        );

        ripId = rips.presetIdToCurrentRipId(presetId);
        uint256 vrfRequestId = rips.requestRandomness(ripId);
        vrfCoordinator.fulfillRandomWords(vrfRequestId, address(rips));
    }

    function _createFeePreset() private returns (uint64) {
        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](1);
        tiers[0] = IRips.PayoutTier({
            payoutCount: uint64(DEFAULT_ENTRY_CAP),
            minPayout: uint128(PAYOUT_PER_ENTRY),
            maxPayout: uint128(PAYOUT_PER_ENTRY)
        });

        vm.prank(owner);
        return rips.createPreset(
            IRips.Config({
                currency: address(0),
                tiers: tiers,
                entryCap: DEFAULT_ENTRY_CAP,
                duration: DEFAULT_DURATION,
                entryPrice: DEFAULT_ENTRY_PRICE,
                feeBps: PROTOCOL_FEE_PERCENT
            })
        );
    }

    function _entryRevenue() private pure returns (uint256) {
        return DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE;
    }

    function _protocolFee() private pure returns (uint256) {
        return _entryRevenue() * PROTOCOL_FEE_PERCENT / 10_000;
    }

    function _referrerFeeFrom(uint256 feeBps) private pure returns (uint256) {
        return _protocolFee() * feeBps / 10_000;
    }

    function _claim() private {
        vm.prank(user);
        rips.claimPayout(ripId, START_INDEX, MAX_CHUNKS, user, referrer);
    }

    function test_GivenReferrerIsZeroAddress() external {
        vm.prank(user);
        rips.claimPayout(ripId, START_INDEX, MAX_CHUNKS, user, address(0));

        assertEq(rips.protocolFeeAccrued(address(0)), _protocolFee());
        assertEq(rips.referrerFeeAccrued(referrer, address(0)), 0);
    }

    function test_GivenNoReferralTiersAreConfiguredAndBaseFeeIsZero() external {
        _claim();

        assertEq(rips.protocolFeeAccrued(address(0)), _protocolFee());
        assertEq(rips.referrerFeeAccrued(referrer, address(0)), 0);
    }

    function test_GivenReferrerHasACustomFeeSet() external {
        vm.prank(owner);
        rips.setReferrerCustomFee(referrer, uint16(CUSTOM_FEE_PERCENT));

        uint256 expectedReferrerFee = _referrerFeeFrom(CUSTOM_FEE_PERCENT);

        vm.expectEmit();
        emit IRips.ReferralFeeAccrued(ripId, referrer, expectedReferrerFee);

        _claim();

        assertEq(rips.referrerFeeAccrued(referrer, address(0)), expectedReferrerFee);
        assertEq(rips.protocolFeeAccrued(address(0)), _protocolFee() - expectedReferrerFee);
    }

    function test_GivenBaseFeeIsSetAndReferrerHasNoPriorActivity() external {
        vm.prank(owner);
        rips.setDefaultReferralFee(uint16(DEFAULT_REFERRAL_FEE));

        uint256 expectedReferrerFee = _referrerFeeFrom(DEFAULT_REFERRAL_FEE);

        vm.expectEmit();
        emit IRips.ReferralFeeAccrued(ripId, referrer, expectedReferrerFee);

        _claim();

        assertEq(rips.referrerFeeAccrued(referrer, address(0)), expectedReferrerFee);
        assertEq(rips.protocolFeeAccrued(address(0)), _protocolFee() - expectedReferrerFee);
    }
}
