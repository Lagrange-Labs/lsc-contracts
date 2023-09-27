// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import {IStrategyManager} from "eigenlayer-contracts/interfaces/IStrategyManager.sol";
import {IStrategy} from "eigenlayer-contracts/interfaces/IStrategy.sol";
import {IDelegationManager} from "eigenlayer-contracts/interfaces/IDelegationManager.sol";
import {ISlasher} from "eigenlayer-contracts/interfaces/ISlasher.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StrategyManager is IStrategyManager {
    IDelegationManager public immutable delegationManager;

    constructor(IDelegationManager _delegation) {
        delegationManager = _delegation;
    }

    function depositIntoStrategy(IStrategy strategy, IERC20 token, uint256 amount) external returns (uint256 shares) {
        return 0;
    }

    function depositBeaconChainETH(address staker, uint256 amount) external {}

    function recordOvercommittedBeaconChainETH(
        address overcommittedPodOwner,
        uint256 beaconChainETHStrategyIndex,
        uint256 amount
    ) external {}

    function depositIntoStrategyWithSignature(
        IStrategy strategy,
        IERC20 token,
        uint256 amount,
        address staker,
        uint256 expiry,
        bytes memory signature
    ) external returns (uint256 shares) {
        return 0;
    }

    function stakerStrategyShares(address user, IStrategy strategy) external view returns (uint256 shares) {
        return 0;
    }

    function getDeposits(address depositor) external view returns (IStrategy[] memory, uint256[] memory) {
        return (new IStrategy[](0), new uint256[](0));
    }

    function stakerStrategyListLength(address staker) external view returns (uint256) {
        return 0;
    }

    function queueWithdrawal(
        uint256[] calldata strategyIndexes,
        IStrategy[] calldata strategies,
        uint256[] calldata shares,
        address withdrawer,
        bool undelegateIfPossible
    ) external returns (bytes32) {
        return 0;
    }

    function completeQueuedWithdrawal(
        QueuedWithdrawal calldata queuedWithdrawal,
        IERC20[] calldata tokens,
        uint256 middlewareTimesIndex,
        bool receiveAsTokens
    ) external {}

    function completeQueuedWithdrawals(
        QueuedWithdrawal[] calldata queuedWithdrawals,
        IERC20[][] calldata tokens,
        uint256[] calldata middlewareTimesIndexes,
        bool[] calldata receiveAsTokens
    ) external {}

    function slashShares(
        address slashedAddress,
        address recipient,
        IStrategy[] calldata strategies,
        IERC20[] calldata tokens,
        uint256[] calldata strategyIndexes,
        uint256[] calldata shareAmounts
    ) external {}

    function slashQueuedWithdrawal(
        address recipient,
        QueuedWithdrawal calldata queuedWithdrawal,
        IERC20[] calldata tokens,
        uint256[] calldata indicesToSkip
    ) external {}

    function calculateWithdrawalRoot(QueuedWithdrawal memory queuedWithdrawal) external pure returns (bytes32) {
        return 0;
    }

    function addStrategiesToDepositWhitelist(IStrategy[] calldata strategiesToWhitelist) external {}

    function removeStrategiesFromDepositWhitelist(IStrategy[] calldata strategiesToRemoveFromWhitelist) external {}

    function delegation() external view returns (IDelegationManager) {
        return delegationManager;
    }

    function slasher() external view returns (ISlasher) {
        return ISlasher(address(0));
    }

    function beaconChainETHStrategy() external view returns (IStrategy) {
        return IStrategy(address(0));
    }

    function withdrawalDelayBlocks() external view returns (uint256) {
        return 0;
    }
}
