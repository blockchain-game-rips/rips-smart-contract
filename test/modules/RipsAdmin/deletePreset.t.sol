// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";

contract Rips_DeletePreset is RipsTestBase {
    uint64 private presetId;

    function setUp() public override {
        super.setUp();

        presetId = _createDefaultPreset();
    }

    function test_RevertWhen_TheCallerIsNotTheOwner() external {
        vm.prank(user);
        vm.expectRevert();
        rips.deletePreset(presetId);
    }

    modifier whenTheCallerIsTheOwner() {
        vm.startPrank(owner);
        _;
        vm.stopPrank();
    }

    function test_RevertWhen_ThePresetDoesNotExist() external whenTheCallerIsTheOwner {
        uint64 nonExistentPresetId = 999;

        vm.expectRevert(IRips.PresetNotExist.selector);
        rips.deletePreset(nonExistentPresetId);
    }

    function test_RevertWhen_ThePresetIsAlreadyDeleted() external whenTheCallerIsTheOwner {
        rips.deletePreset(presetId);

        vm.expectRevert(IRips.PresetNotExist.selector);
        rips.deletePreset(presetId);
    }

    function test_WhenThePresetIsNotDeleted() external whenTheCallerIsTheOwner {
        vm.expectEmit();
        emit IRips.PresetDeleted(presetId);
        rips.deletePreset(presetId);
    }
}
