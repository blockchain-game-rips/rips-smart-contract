// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract Rips_SetReferralTiers is RipsTestBase {
    event ReferralTiersUpdated(address indexed currency, IRips.ReferralTier[] tiers);

    address internal constant CURRENCY = address(0);

    function _validTiers() private pure returns (IRips.ReferralTier[] memory tiers) {
        tiers = new IRips.ReferralTier[](2);
        tiers[0] = IRips.ReferralTier({minVolume: 1 ether, feeBps: 500});
        tiers[1] = IRips.ReferralTier({minVolume: 10 ether, feeBps: 1000});
    }

    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        vm.prank(user);
        vm.expectRevert();
        rips.setReferralTiers(CURRENCY, _validTiers());
    }

    modifier whenTheCallerIsTheOwner() {
        vm.startPrank(owner);
        _;
        vm.stopPrank();
    }

    function test_RevertWhen_TiersCountExceedsMaxReferralTierCount()
        external
        whenTheCallerIsTheOwner
    {
        uint256 maxCount = rips.MAX_REFERRAL_TIER_COUNT();
        IRips.ReferralTier[] memory tiers = new IRips.ReferralTier[](maxCount + 1);

        for (uint256 i = 0; i < tiers.length; i++) {
            tiers[i] = IRips.ReferralTier({minVolume: uint128(i + 1) * 1 ether, feeBps: 100});
        }

        vm.expectRevert(IRips.ReferralTierCountExceeded.selector);
        rips.setReferralTiers(CURRENCY, tiers);
    }

    function test_RevertWhen_TiersAreNotSortedByMinVolumeAscending()
        external
        whenTheCallerIsTheOwner
    {
        IRips.ReferralTier[] memory tiers = new IRips.ReferralTier[](2);
        tiers[0] = IRips.ReferralTier({minVolume: 10 ether, feeBps: 1000});
        tiers[1] = IRips.ReferralTier({minVolume: 1 ether, feeBps: 500});

        vm.expectRevert(IRips.ReferralTiersNotSorted.selector);
        rips.setReferralTiers(CURRENCY, tiers);
    }

    function test_RevertWhen_TiersHaveDuplicateMinVolumeValues() external whenTheCallerIsTheOwner {
        IRips.ReferralTier[] memory tiers = new IRips.ReferralTier[](2);
        tiers[0] = IRips.ReferralTier({minVolume: 1 ether, feeBps: 500});
        tiers[1] = IRips.ReferralTier({minVolume: 1 ether, feeBps: 1000});

        vm.expectRevert(IRips.ReferralTiersNotSorted.selector);
        rips.setReferralTiers(CURRENCY, tiers);
    }

    function test_RevertWhen_ATierFeeBpsExceedsFeeBase() external whenTheCallerIsTheOwner {
        IRips.ReferralTier[] memory tiers = new IRips.ReferralTier[](1);
        tiers[0] = IRips.ReferralTier({minVolume: 1 ether, feeBps: uint16(rips.FEE_BASE()) + 1});

        vm.expectRevert(IRips.FeeTooHigh.selector);
        rips.setReferralTiers(CURRENCY, tiers);
    }

    function test_WhenTiersAreValid() external whenTheCallerIsTheOwner {
        IRips.ReferralTier[] memory tiers = _validTiers();

        vm.expectEmit();
        emit ReferralTiersUpdated(CURRENCY, tiers);

        rips.setReferralTiers(CURRENCY, tiers);

        // verify previously stored tiers are replaced
        rips.setReferralTiers(CURRENCY, tiers);

        IRips.ReferralTier[] memory stored = rips.getReferralTiers(CURRENCY);

        assertEq(stored[0].minVolume, tiers[0].minVolume);
        assertEq(stored[0].feeBps, tiers[0].feeBps);
        assertEq(stored[1].minVolume, tiers[1].minVolume);
        assertEq(stored[1].feeBps, tiers[1].feeBps);
    }

    function test_WhenTiersAreSetForDifferentCurrencies() external whenTheCallerIsTheOwner {
        address currencyB = makeAddr("currencyB");

        IRips.ReferralTier[] memory tiersA = new IRips.ReferralTier[](1);
        tiersA[0] = IRips.ReferralTier({minVolume: 1 ether, feeBps: 500});

        IRips.ReferralTier[] memory tiersB = new IRips.ReferralTier[](1);
        tiersB[0] = IRips.ReferralTier({minVolume: 5 ether, feeBps: 1000});

        rips.setReferralTiers(CURRENCY, tiersA);
        rips.setReferralTiers(currencyB, tiersB);

        IRips.ReferralTier[] memory storedA = rips.getReferralTiers(CURRENCY);
        IRips.ReferralTier[] memory storedB = rips.getReferralTiers(currencyB);

        assertEq(storedA[0].minVolume, tiersA[0].minVolume);
        assertEq(storedB[0].minVolume, tiersB[0].minVolume);
    }
}
