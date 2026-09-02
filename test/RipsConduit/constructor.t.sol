// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../RipsTestBase.sol";
import {RipsConduit} from "../../src/RipsConduit.sol";

contract RipsConduit_Constructor is RipsTestBase {
    modifier whenTheAddressDoesNotClaimTheRipsInterface() {
        _;
    }

    function test_RevertGiven_TheAddressIsTheZeroAddress() external whenTheAddressDoesNotClaimTheRipsInterface {
        vm.expectRevert(RipsConduit.NotRips.selector);
        new RipsConduit(address(0));
    }

    function test_RevertGiven_TheAddressHasNoCode() external whenTheAddressDoesNotClaimTheRipsInterface {
        vm.expectRevert(RipsConduit.NotRips.selector);
        new RipsConduit(makeAddr("eoa"));
    }

    function test_RevertGiven_TheAddressIsAnUnrelatedContract() external whenTheAddressDoesNotClaimTheRipsInterface {
        vm.expectRevert(RipsConduit.NotRips.selector);
        new RipsConduit(address(erc20));
    }

    function test_WhenTheAddressClaimsTheRipsInterface() external {
        RipsConduit conduit = new RipsConduit(address(rips));

        assertEq(address(conduit.rips()), address(rips));
    }
}
