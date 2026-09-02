// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import "../script/VrfSetup.sol";

library VrfHelper {
    function deployCoordinator() internal returns (VRFCoordinatorV2_5Mock coordinator, uint256 subscriptionId) {
        coordinator = new VRFCoordinatorV2_5Mock(VRF_BASE_FEE, VRF_GAS_PRICE, VRF_WEI_PER_UNIT_LINK);
        subscriptionId = coordinator.createSubscription();
        coordinator.fundSubscription(subscriptionId, VRF_FUND_AMOUNT);
    }
}
