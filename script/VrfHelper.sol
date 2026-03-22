// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

library VrfHelper {
    uint96 internal constant BASE_FEE = 0.1 ether;
    uint96 internal constant GAS_PRICE = 1 gwei;
    int256 internal constant WEI_PER_UNIT_LINK = 4e15;
    uint256 internal constant FUND_AMOUNT = 10 ether;

    function deployCoordinator()
        internal
        returns (VRFCoordinatorV2_5Mock coordinator, uint256 subscriptionId)
    {
        coordinator = new VRFCoordinatorV2_5Mock(BASE_FEE, GAS_PRICE, WEI_PER_UNIT_LINK);
        subscriptionId = coordinator.createSubscription();
        coordinator.fundSubscription(subscriptionId, FUND_AMOUNT);
    }
}
