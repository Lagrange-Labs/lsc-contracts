// SPDX-License-Identifier: BUSL-1.1

/* eslint-disable */
// forgefmt: disable-start

pragma solidity ^0.8.12;

import {IStrategyManager} from "eigenlayer-contracts/src/contracts/interfaces/IStrategyManager.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {IDelegationManager} from "eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
import {ISlasher} from "eigenlayer-contracts/src/contracts/interfaces/ISlasher.sol";
import {IEigenPodManager} from "eigenlayer-contracts/src/contracts/interfaces/IEigenPodManager.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract StrategyManager is IStrategyManager {
    IDelegationManager public immutable delegationManager;

    constructor(IDelegationManager _delegation) {
        delegationManager = _delegation;
    }

    function depositIntoStrategy(IStrategy /*strategy*/, IERC20 /*token*/, uint256 /*amount*/) external pure returns (uint256 shares) {
        return 0;
    }

    function depositIntoStrategyWithSignature(
        IStrategy /*strategy*/,
        IERC20 /*token*/,
        uint256 /*amount*/,
        address /*staker*/,
        uint256 /*expiry*/,
        bytes memory /*signature*/
    ) external pure returns (uint256 shares) {
        return 0;
    }

    function removeShares(address /*staker*/, IStrategy /*strategy*/, uint256 /*shares*/) external pure {}

    function addShares(address /*staker*/, IStrategy /*strategy*/, uint256 /*shares*/) external pure {}

    function withdrawSharesAsTokens(
        address /*staker*/,
        IStrategy /*strategy*/,
        uint256 /*shares*/,
        IERC20 /*token*/
    ) external pure {}

    function stakerStrategyShares(address /*staker*/, IStrategy /*strategy*/) external pure returns (uint256 shares) {
        return 0;
    }

    function getDeposits(address /*depositor*/) external pure returns (IStrategy[] memory, uint256[] memory) {
        return (new IStrategy[](0), new uint256[](0));
    }

    function stakerStrategyListLength(address /*staker*/) external pure returns (uint256) {
        return 0;
    }

    function addStrategiesToDepositWhitelist(IStrategy[] calldata /*strategiesToWhitelist*/) external pure {}

    function removeStrategiesFromDepositWhitelist(IStrategy[] calldata /*strategiesToRemoveFromWhitelist*/) external {}

    function delegation() external view returns (IDelegationManager) {
        return delegationManager;
    }

    function slasher() external pure returns (ISlasher) {
        return ISlasher(address(0));
    }

    function eigenPodManager() external pure returns (IEigenPodManager) {
        return IEigenPodManager(address(0));
    }

    function strategyWhitelister() external pure returns (address) {
        return address(0);
    }

    function migrateQueuedWithdrawal(DeprecatedStruct_QueuedWithdrawal calldata /*queuedWithdrawal*/) external pure returns (bool, bytes32) {
        return (false, bytes32(0));
    }

    function calculateWithdrawalRoot(DeprecatedStruct_QueuedWithdrawal calldata /*queuedWithdrawal*/) external pure returns (bytes32) {
        return bytes32(0);
    }
}
