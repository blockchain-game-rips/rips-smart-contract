// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IRips} from "./interfaces/IRips.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @notice Entry point for bridges that cannot receive native currency back.
///
/// Rips refunds native excess to the caller, because the payment is pulled from
/// the caller and the change belongs to them. A bridge router calling Rips
/// directly is that caller, and a router without a `receive()` function reverts
/// on the refund, which sends the whole order to the bridge fallback address.
///
/// The conduit stands in as the caller so the refund lands here, then forwards
/// it to the recipient the order was placed for.
contract RipsConduit {
    error NotRips();
    error TransferFailed();

    IRips public immutable rips;

    event ExcessForwarded(address indexed recipient, uint256 amount);

    /// @dev Guards against a mistyped address at deployment, not a hostile one:
    /// any contract can claim the interface.
    constructor(address ripsAddress) {
        if (!_claimsRipsInterface(ripsAddress)) revert NotRips();

        rips = IRips(ripsAddress);
    }

    /// @dev A call to an address without code succeeds returning nothing, and
    /// the empty return reverts on decode rather than entering the catch.
    function _claimsRipsInterface(address account) private view returns (bool) {
        if (account.code.length == 0) return false;

        try IERC165(account).supportsInterface(type(IRips).interfaceId) returns (bool supported) {
            return supported;
        } catch {
            return false;
        }
    }

    function enterRip(uint64 presetId, uint64 entryCount, address recipient) external payable {
        rips.enterRip{value: msg.value}(presetId, entryCount, recipient);

        _forwardBalance(recipient);
    }

    /// @dev Receives the native excess Rips refunds by a plain call.
    receive() external payable {}

    /// @dev Sweeps the whole balance, not just this order's refund, so anything
    /// stranded here leaves with the next order.
    function _forwardBalance(address recipient) private {
        uint256 amount = address(this).balance;

        if (amount == 0) return;

        (bool success,) = recipient.call{value: amount}("");

        if (!success) revert TransferFailed();

        emit ExcessForwarded(recipient, amount);
    }
}
