// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract Rips_SetReferralTiers is RipsTestBase {
    event ReferralTiersUpdated(IRips.ReferralTier[] tiers);

    function _validTiers() private pure returns (IRips.ReferralTier[] memory tiers) {
        tiers = new IRips.ReferralTier[](2);
        tiers[0] = IRips.ReferralTier({minVolume: 1 ether, feePercent: 500});
        tiers[1] = IRips.ReferralTier({minVolume: 10 ether, feePercent: 1000});
    }

    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        vm.prank(user);
        vm.expectRevert();
        rips.setReferralTiers(_validTiers());
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
            tiers[i] = IRips.ReferralTier({minVolume: uint128(i + 1) * 1 ether, feePercent: 100});
        }

        vm.expectRevert(IRips.ReferralTierCountExceeded.selector);
        rips.setReferralTiers(tiers);
    }

    function test_RevertWhen_TiersAreNotSortedByMinVolumeAscending()
        external
        whenTheCallerIsTheOwner
    {
        IRips.ReferralTier[] memory tiers = new IRips.ReferralTier[](2);
        tiers[0] = IRips.ReferralTier({minVolume: 10 ether, feePercent: 1000});
        tiers[1] = IRips.ReferralTier({minVolume: 1 ether, feePercent: 500});

        vm.expectRevert(IRips.ReferralTiersNotSorted.selector);
        rips.setReferralTiers(tiers);
    }

    function test_RevertWhen_TiersHaveDuplicateMinVolumeValues() external whenTheCallerIsTheOwner {
        IRips.ReferralTier[] memory tiers = new IRips.ReferralTier[](2);
        tiers[0] = IRips.ReferralTier({minVolume: 1 ether, feePercent: 500});
        tiers[1] = IRips.ReferralTier({minVolume: 1 ether, feePercent: 1000});

        vm.expectRevert(IRips.ReferralTiersNotSorted.selector);
        rips.setReferralTiers(tiers);
    }

    function test_WhenTiersAreValid() external whenTheCallerIsTheOwner {
        IRips.ReferralTier[] memory tiers = _validTiers();

        vm.expectEmit();
        emit ReferralTiersUpdated(tiers);

        rips.setReferralTiers(tiers);

        // verify previously stored tiers are replaced
        rips.setReferralTiers(tiers);

        (uint128 minVolume0, uint16 feePercent0) = rips.referralTiers(0);
        (uint128 minVolume1, uint16 feePercent1) = rips.referralTiers(1);

        assertEq(minVolume0, tiers[0].minVolume);
        assertEq(feePercent0, tiers[0].feePercent);
        assertEq(minVolume1, tiers[1].minVolume);
        assertEq(feePercent1, tiers[1].feePercent);
    }
}
