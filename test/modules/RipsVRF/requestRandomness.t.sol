// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../../RipsTestBase.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";

contract StubVrfCoordinator is IVRFCoordinatorV2Plus {
    uint256 private _nextRequestId;

    function setNextRequestId(uint256 requestId) external {
        _nextRequestId = requestId;
    }

    function requestRandomWords(VRFV2PlusClient.RandomWordsRequest calldata)
        external
        override
        returns (uint256)
    {
        return _nextRequestId;
    }

    function addConsumer(uint256, address) external override {}

    function removeConsumer(uint256, address) external override {}

    function cancelSubscription(uint256, address) external override {}

    function acceptSubscriptionOwnerTransfer(uint256) external override {}

    function createSubscription() external override returns (uint256) {
        return 0;
    }

    function fundSubscriptionWithNative(uint256) external payable override {}

    function getSubscription(uint256)
        external
        pure
        override
        returns (uint96, uint96, uint64, address, address[] memory)
    {
        return (0, 0, 0, address(0), new address[](0));
    }

    function getActiveSubscriptionIds(uint256, uint256)
        external
        pure
        override
        returns (uint256[] memory)
    {
        return new uint256[](0);
    }

    function requestSubscriptionOwnerTransfer(uint256, address) external override {}

    function pendingRequestExists(uint256) external pure override returns (bool) {
        return false;
    }
}

contract Rips_RequestRandomness is RipsTestBase {
    event RandomnessRequested(uint256 indexed ripId, uint256 vrfRequestId);

    event RandomWordsRequested(
        bytes32 indexed keyHash,
        uint256 requestId,
        uint256 preSeed,
        uint256 indexed subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords,
        bytes extraArgs,
        address indexed sender
    );

    uint64 private constant ENTRY_CAP = 2;
    uint256 private constant ENTRY_PRICE = 1 ether;
    uint256 private constant EXPECTED_FIRST_REQUEST_ID = 1;

    uint64 private presetId;
    uint256 private soldOutRipId;
    uint256 private activeRipId;

    function setUp() public override {
        super.setUp();

        IRips.PayoutTier[] memory tiers = new IRips.PayoutTier[](1);
        tiers[0] = IRips.PayoutTier({
            payoutCount: uint64(ENTRY_CAP),
            minPayout: uint128(ENTRY_PRICE),
            maxPayout: uint128(ENTRY_PRICE)
        });

        vm.startPrank(owner);
        presetId = rips.createPreset(
            IRips.Config({
                currency: address(0),
                tiers: tiers,
                entryCap: ENTRY_CAP,
                duration: 1 days,
                entryPrice: ENTRY_PRICE,
                feePercent: 0
            })
        );
        vm.stopPrank();

        vm.deal(user, ENTRY_CAP * ENTRY_PRICE);
        vm.prank(user);
        rips.enterRip{value: ENTRY_CAP * ENTRY_PRICE}(presetId, ENTRY_CAP, user);

        soldOutRipId = rips.presetIdToCurrentRipId(presetId);

        // create a second preset and enter one entry to initialize the rip (but not sell out)
        vm.prank(owner);
        uint64 presetId2 = rips.createPreset(
            IRips.Config({
                currency: address(0),
                tiers: tiers,
                entryCap: ENTRY_CAP,
                duration: 1 days,
                entryPrice: ENTRY_PRICE,
                feePercent: 0
            })
        );
        vm.deal(user, ENTRY_PRICE);
        vm.prank(user);
        rips.enterRip{value: ENTRY_PRICE}(presetId2, 1, user);
        activeRipId = rips.presetIdToCurrentRipId(presetId2);
    }

    function test_RevertWhen_TheRipDoesNotExist() external {
        uint256 nonExistentRipId = 999;
        vm.expectRevert(IRips.RipNotExist.selector);
        rips.requestRandomness(nonExistentRipId);
    }

    function test_RevertWhen_TheVrfRequestStatusIsNotNotRequested() external {
        // request once to move status to Requested
        vrfCoordinator.fundSubscription(vrfSubscriptionId, 100 ether);
        rips.requestRandomness(soldOutRipId);

        vm.expectRevert(IRips.VrfAlreadyRequested.selector);
        rips.requestRandomness(soldOutRipId);
    }

    function test_RevertWhen_TheRipIsNotSoldOut() external {
        vm.expectRevert(IRips.RipNotSoldOut.selector);
        rips.requestRandomness(activeRipId);
    }

    function test_RevertWhen_TheVRFCoordinatorReturnsAZeroRequestId() external {
        StubVrfCoordinator stub = new StubVrfCoordinator();
        stub.setNextRequestId(0);

        vm.prank(owner);
        rips.setCoordinator(address(stub));

        vm.expectRevert(IRips.InvalidRequestId.selector);
        rips.requestRandomness(soldOutRipId);
    }

    function test_RevertWhen_TheVRFCoordinatorReturnsARequestIdAlreadyMappedToARip() external {
        uint256 duplicateRequestId = 1;

        StubVrfCoordinator stub = new StubVrfCoordinator();
        stub.setNextRequestId(duplicateRequestId);

        vm.prank(owner);
        rips.setCoordinator(address(stub));

        // first request succeeds and maps duplicateRequestId → soldOutRipId
        rips.requestRandomness(soldOutRipId);

        // create a second sold-out rip
        uint64 presetId2 = _createDefaultPreset();

        vm.deal(user, DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE);
        vm.prank(user);
        rips.enterRip{value: DEFAULT_ENTRY_CAP * DEFAULT_ENTRY_PRICE}(
            presetId2, DEFAULT_ENTRY_CAP, user
        );

        uint256 secondRipId = rips.presetIdToCurrentRipId(presetId2);

        vm.expectRevert(IRips.InvalidRequestId.selector);
        rips.requestRandomness(secondRipId);
    }

    modifier whenTheRipExistsIsActiveAndIsSoldOut() {
        vrfCoordinator.fundSubscription(vrfSubscriptionId, 100 ether);
        _;
    }

    function test_WhenTheRipExistsIsActiveAndIsSoldOut()
        external
        whenTheRipExistsIsActiveAndIsSoldOut
    {
        vm.expectEmit(true, true, true, false, address(vrfCoordinator));
        emit RandomWordsRequested(
            VRF_KEY_HASH,
            0,
            0,
            vrfSubscriptionId,
            rips.vrfRequestConfirmations(),
            VRF_CALLBACK_GAS_LIMIT,
            rips.VRF_NUM_WORDS(),
            "",
            address(rips)
        );

        vm.expectEmit();
        emit RandomnessRequested(soldOutRipId, EXPECTED_FIRST_REQUEST_ID);

        uint256 requestId = rips.requestRandomness(soldOutRipId);

        assertEq(requestId, EXPECTED_FIRST_REQUEST_ID);

        IRips.Rip memory rip = rips.exposed_rip(soldOutRipId);
        assertEq(uint8(rip.vrfRequestStatus), uint8(IRips.VrfRequestStatus.Requested));

        assertEq(rips.exposed_requestTimestamp(soldOutRipId), block.timestamp);
    }
}
