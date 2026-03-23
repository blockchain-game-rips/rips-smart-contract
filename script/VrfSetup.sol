// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

uint96 constant VRF_BASE_FEE = 0.1 ether;
uint96 constant VRF_GAS_PRICE = 1 gwei;
int256 constant VRF_WEI_PER_UNIT_LINK = 4e15;
uint256 constant VRF_FUND_AMOUNT = 10 ether;

//TODO: extract subscriptionId from event and get rid of this contract
contract VrfSetup {
    VRFCoordinatorV2_5Mock public coordinator;
    uint256 public subscriptionId;

    constructor() {
        coordinator = new VRFCoordinatorV2_5Mock(VRF_BASE_FEE, VRF_GAS_PRICE, VRF_WEI_PER_UNIT_LINK);
        subscriptionId = coordinator.createSubscription();
        coordinator.fundSubscription(subscriptionId, VRF_FUND_AMOUNT);
    }

    function addConsumer(address consumer) external {
        coordinator.addConsumer(subscriptionId, consumer);
    }
}
