// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./modules/RipsVrf.sol";
import "./modules/RipsReferral.sol";
import "./libraries/RipsMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Rips is RipsVrf, RipsReferral, ReentrancyGuard {
    using SafeERC20 for IERC20;

    constructor(
        address vrfCoordinator,
        uint256 vrfSubscriptionId,
        bytes32 vrfKeyHash,
        uint32 callbackGasLimit
    ) RipsVrf(vrfCoordinator, vrfSubscriptionId, vrfKeyHash, callbackGasLimit) {
        setFeeRecipient(msg.sender);
    }

    function buyTickets(uint256 stakeId, uint256 ticketCount, address recipient)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        if (recipient == address(0)) revert ZeroAddress();
        if (ticketCount == 0) revert ZeroTickets();

        (uint256 roundId, Round storage round, Config storage config) =
            _resolveRoundAndConfig(stakeId);

        uint256 toBuy = _getTicketsToBuy(round, config, ticketCount);

        _purchaseTickets(roundId, round, recipient, toBuy);

        uint256 nativeExcess = _receivePayment(config, toBuy, msg.sender);

        if (nativeExcess > 0) {
            _sendNative(msg.sender, nativeExcess);
        }
    }

    function _getTicketsToBuy(Round storage round, Config storage config, uint256 ticketCount)
        internal
        view
        returns (uint256)
    {
        uint256 available = config.ticketCap - round.ticketsSold;

        return ticketCount > available ? available : ticketCount;
    }

    function _purchaseTickets(
        uint256 roundId,
        Round storage round,
        address recipient,
        uint256 ticketsToBuy
    ) internal {
        uint256 startTicket = round.ticketsSold;

        round.ticketsSold += uint32(ticketsToBuy);

        _storeTicketRanges(roundId, recipient, startTicket, ticketsToBuy);

        emit TicketsPurchased(roundId, recipient, ticketsToBuy, startTicket);
    }

    function _resolveRoundAndConfig(uint256 stakeId)
        private
        returns (uint256 roundId, Round storage round, Config storage config)
    {
        roundId = stakeIdToCurrentRoundId[stakeId];

        if (roundId != 0) {
            round = roundIdToRound[roundId];
            config = configIdToConfig[round.configId];

            // round is filling
            if (!_isExpired(round, config) && !_isSoldOut(round, config)) {
                return (roundId, round, config);
            }
        }

        if (isStakeDeleted[stakeId]) revert StakeNotExist();

        // stake is fresh, no round yet
        if (roundId == 0) {
            uint256 configId = stakeIdToCurrentConfigId[stakeId];

            // ticketCap is guaranteed non-zero by isPowerOfTwo validation
            if (configIdToConfig[configId].ticketCap == 0) revert StakeNotExist();
        }

        // round is sold out or expired
        return _createRound(stakeId);
    }

    function _createRound(uint256 stakeId)
        internal
        returns (uint256 roundId, Round storage round, Config storage config)
    {
        roundId = _nextRoundId++;
        round = roundIdToRound[roundId];

        uint256 configId = stakeIdToCurrentConfigId[stakeId];
        config = configIdToConfig[configId];

        round.stakeId = uint64(stakeId);
        round.configId = uint64(configId);
        round.startTime = uint40(block.timestamp);
        round.status = RoundStatus.Active;

        stakeIdToCurrentRoundId[stakeId] = roundId;

        emit RoundCreated(roundId, stakeId);
    }

    function claimPrizes(
        uint256 roundId,
        uint256 startIndex,
        uint256 maxRanges,
        address recipient,
        address referrer
    ) external nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();
        if (msg.sender != recipient && msg.sender != owner()) revert NotRecipientOrOwner();

        Round storage round = roundIdToRound[roundId];
        if (round.status != RoundStatus.Finalized) revert RoundNotFinalized();

        TicketRange[] storage ranges = _userTickets[roundId][recipient];
        if (startIndex >= ranges.length) revert InvalidStartIndex();

        Config storage config = configIdToConfig[round.configId];

        (uint256 ticketCount, uint256 totalPrize) =
            _accumulateClaimedPrizes(ranges, startIndex, maxRanges, round, config);

        if (totalPrize > 0) {
            _distributePrize(roundId, round, recipient, referrer, ticketCount, totalPrize);
        }
    }

    function _distributePrize(
        uint256 roundId,
        Round storage round,
        address recipient,
        address referrer,
        uint256 ticketCount,
        uint256 prize
    ) private {
        Config storage config = configIdToConfig[round.configId];
        address currency = config.currency;

        uint256 protocolFee = (prize * config.feePercent) / 10000;
        uint256 userPrize = prize - protocolFee;

        if (protocolFee > 0) {
            uint256 referrerFee = _collectReferrerFee(referrer, protocolFee, prize);
            uint256 remainingFee = protocolFee - referrerFee;

            if (remainingFee > 0) {
                _transfer(currency, feeRecipient, remainingFee);
            }

            if (referrerFee > 0) {
                _transfer(currency, referrer, referrerFee);
                emit ReferralFeePaid(roundId, referrer, referrerFee);
            }
        }

        //TODO: ensure that protocol fee < 100%
        _transfer(currency, recipient, userPrize);

        emit PrizesClaimed(roundId, recipient, referrer, ticketCount, userPrize);
    }

    function _receivePayment(Config storage config, uint256 toBuy, address from)
        private
        returns (uint256 nativeExcess)
    {
        uint256 requiredPayment = toBuy * config.ticketCost;
        address currency = config.currency;

        if (_isNative(currency)) {
            if (msg.value < requiredPayment) revert IncorrectPayment();

            nativeExcess = msg.value - requiredPayment;
        } else {
            if (msg.value != 0) revert EthSentForERC20();

            IERC20(currency).safeTransferFrom(from, address(this), requiredPayment);
        }
    }

    function _transfer(address currency, address to, uint256 amount) private {
        if (_isNative(currency)) {
            _sendNative(to, amount);
        } else {
            IERC20(currency).safeTransfer(to, amount);
        }
    }

    function _sendNative(address to, uint256 amount) private {
        (bool success,) = to.call{value: amount}("");

        if (!success) revert TransferFailed();
    }

    struct PrizeCalcParams {
        uint256 a;
        uint256 b;
        uint256 n;
        PrizeTier[] tiers;
        uint64[] bounds;
    }

    function _accumulateClaimedPrizes(
        TicketRange[] storage ranges,
        uint256 startIndex,
        uint256 maxRanges,
        Round storage round,
        Config storage config
    ) private returns (uint256 ticketCount, uint256 totalPrize) {
        PrizeCalcParams memory p = PrizeCalcParams({
            a: round.randomA,
            b: round.randomB,
            n: config.ticketCap,
            tiers: config.prizeDistribution,
            bounds: configIdToTierBoundaries[round.configId]
        });

        uint256 endIndex = startIndex + maxRanges;
        if (endIndex > ranges.length) endIndex = ranges.length;

        for (uint256 i = startIndex; i < endIndex; i++) {
            if (ranges[i].claimed) continue;

            uint256 rangeStart = ranges[i].start;
            uint256 count = ranges[i].count;

            for (uint256 j = 0; j < count; j++) {
                //TODO: try to pass memory struct and see gas consumption diff
                totalPrize += RipsMath.calculateTicketPrize(
                    rangeStart + j + 1, p.a, p.b, p.n, p.tiers, p.bounds
                );
            }

            ticketCount += count;

            ranges[i].claimed = true;
        }
    }

    function refund(uint256 roundId, address recipient) external nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();

        Round storage round = roundIdToRound[roundId];
        if (round.stakeId == 0) revert RoundNotExist();

        Config storage config = configIdToConfig[round.configId];

        if (!_isExpired(round, config) && !_isSoldOut(round, config)) revert RoundNotExpired();
        if (_hasRefunded[roundId][recipient]) revert AlreadyRefunded();

        uint256 ticketCount = _userTicketCount[roundId][recipient];
        if (ticketCount == 0) revert NoTicketsToRefund();

        _hasRefunded[roundId][recipient] = true;
        _transfer(config.currency, recipient, ticketCount * config.ticketCost);

        emit RefundIssued(roundId, recipient, ticketCount);
    }

    function _isExpired(Round storage round, Config storage config) internal view returns (bool) {
        return block.timestamp > round.startTime + config.duration;
    }

    function _isSoldOut(Round storage round, Config storage config) internal view returns (bool) {
        return round.ticketsSold == config.ticketCap;
    }

    function getUserTickets(uint256 roundId, address user)
        external
        view
        returns (TicketRange[] memory)
    {
        return _userTickets[roundId][user];
    }

    function _storeTicketRanges(
        uint256 roundId,
        address buyer,
        uint256 startTicket,
        uint256 ticketCount
    ) private {
        TicketRange[] storage ranges = _userTickets[roundId][buyer];
        uint256 remaining = ticketCount;
        uint256 currentStart = startTicket;

        while (remaining > 0) {
            uint256 rangeSize =
                remaining > MAX_TICKETS_PER_RANGE ? MAX_TICKETS_PER_RANGE : remaining;
            ranges.push(
                TicketRange({start: uint96(currentStart), count: uint96(rangeSize), claimed: false})
            );
            currentStart += rangeSize;
            remaining -= rangeSize;
        }

        _userTicketCount[roundId][buyer] += ticketCount;
    }

    function _isNative(address currency) private pure returns (bool) {
        return currency == address(0);
    }
}
