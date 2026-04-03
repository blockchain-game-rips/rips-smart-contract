// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract Rips_UpdateVrfKeyHash is RipsTestBase {
    event VrfKeyHashUpdated(bytes32 newKeyHash);

    bytes32 private constant NEW_KEY_HASH = keccak256("new_key_hash");

    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        vm.prank(user);
        vm.expectRevert();
        rips.updateVrfKeyHash(NEW_KEY_HASH);
    }

    modifier whenTheCallerIsTheOwner() {
        vm.prank(owner);
        _;
    }

    function test_WhenTheCallerIsTheOwner() external whenTheCallerIsTheOwner {
        vm.expectEmit();
        emit VrfKeyHashUpdated(NEW_KEY_HASH);

        rips.updateVrfKeyHash(NEW_KEY_HASH);

        assertEq(rips.vrfKeyHash(), NEW_KEY_HASH);
    }
}
