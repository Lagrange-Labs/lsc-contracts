// SPDX-License-Identifier: BUSL-1.1

/* eslint-disable */
// forgefmt: disable-start

pragma solidity ^0.8.20;

import {IDelegationManager} from "eigenlayer-contracts/src/contracts/interfaces/IDelegationManager.sol";
import {IStrategy} from "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
import {ISignatureUtils} from "eigenlayer-contracts/src/contracts/interfaces/ISignatureUtils.sol";
import {IStrategyManager} from "eigenlayer-contracts/src/contracts/interfaces/IStrategyManager.sol";

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DelegationManager is IDelegationManager {
    mapping(address => uint256) private _operatorShares;
    address private _owner;

    constructor() {
        _owner = msg.sender;
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
    }

    function registerAsOperator(OperatorDetails calldata /*registeringOperatorDetails*/, string calldata /*metadataURI*/) external {
        _operatorShares[msg.sender] = 100000000000000000;
    }

    function modifyOperatorDetails(OperatorDetails calldata /*newOperatorDetails*/) external pure {}

    function updateOperatorMetadataURI(string calldata /*metadataURI*/) external pure {}

    function updateAVSMetadataURI(string calldata /*metadataURI*/) external pure {}

    function delegateTo(address /*operator*/, SignatureWithExpiry memory /*approverSignatureAndExpiry*/,
        bytes32 /*approverSalt*/) external pure {}

    function delegateToBySignature(address /*staker*/, address /*operator*/, SignatureWithExpiry memory /*stakerSignatureAndExpiry*/,
        SignatureWithExpiry memory /*approverSignatureAndExpiry*/,
        bytes32 /*approverSalt*/) external pure {}

    function undelegate(address /*staker*/) external pure returns (bytes32[] memory withdrawalRoot) {}

    function queueWithdrawals(
        QueuedWithdrawalParams[] calldata /*queuedWithdrawalParams*/
    ) external pure returns (bytes32[] memory) {}

    function completeQueuedWithdrawal(
        Withdrawal calldata /*withdrawal*/,
        IERC20[] calldata /*tokens*/,
        uint256 /*middlewareTimesIndex*/,
        bool /*receiveAsTokens*/
    ) external pure {}

    function completeQueuedWithdrawals(
        Withdrawal[] calldata /*withdrawals*/,
        IERC20[][] calldata /*tokens*/,
        uint256[] calldata /*middlewareTimesIndexes*/,
        bool[] calldata /*receiveAsTokens*/
    ) external pure {}

    function increaseDelegatedShares(address /*staker*/, IStrategy /*strategy*/, uint256 /*shares*/) external pure {}

    function decreaseDelegatedShares(address /*staker*/, IStrategy /*strategy*/, uint256 /*shares*/)
        external pure {}

    function registerOperatorToAVS(
        address /*operator*/,
        ISignatureUtils.SignatureWithSaltAndExpiry memory /*operatorSignature*/
    ) external pure {}

    function deregisterOperatorFromAVS(address /*operator*/) external pure {}

    function operatorSaltIsSpent(address /*operator*/, bytes32 /*salt*/) external pure returns (bool) {}

    function calculateOperatorAVSRegistrationDigestHash(
        address /*operator*/,
        address /*avs*/,
        bytes32 /*salt*/,
        uint256 /*expiry*/
    ) external pure returns (bytes32) {}

    function delegatedTo(address /*staker*/) external pure returns (address) {}

    function operatorDetails(address /*operator*/) external pure returns (OperatorDetails memory) {}

    function earningsReceiver(address /*operator*/) external pure returns (address) {}

    function delegationApprover(address /*operator*/) external pure returns (address) {}

    function stakerOptOutWindowBlocks(address /*operator*/) external view returns (uint256){}


    function operatorShares(address operator, IStrategy /*strategy*/) external view returns (uint256) {
        return _operatorShares[operator];
    }

    function isDelegated(address /*staker*/) external pure returns (bool) {
        return false;
    }
   
    function isOperator(address /*operator*/) external pure returns (bool) {
        return false;
    }

    function stakerNonce(address /*staker*/) external pure returns (uint256) {}

    function delegationApproverSaltIsSpent(address /*_delegationApprover*/, bytes32 /*salt*/) external pure returns (bool) {}

    function withdrawalDelayBlocks() external pure returns (uint256) {}

    function calculateCurrentStakerDelegationDigestHash(
        address /*staker*/,
        address /*operator*/,
        uint256 /*expiry*/
    ) external pure returns (bytes32) {}

    function calculateStakerDelegationDigestHash(
        address /*staker*/,
        uint256 /*_stakerNonce*/,
        address /*operator*/,
        uint256 /*expiry*/
    ) external pure returns (bytes32) {}

    function calculateDelegationApprovalDigestHash(
        address /*staker*/,
        address /*operator*/,
        address /*approver*/,
        bytes32 /*salt*/,
        uint256 /*expiry*/
    ) external pure returns (bytes32) {}

    function DOMAIN_TYPEHASH() external pure returns (bytes32) {}

    function STAKER_DELEGATION_TYPEHASH() external pure returns (bytes32) {}

    function DELEGATION_APPROVAL_TYPEHASH() external pure returns (bytes32) {}

    function OPERATOR_AVS_REGISTRATION_TYPEHASH() external pure returns (bytes32) {}

    function domainSeparator() external pure returns (bytes32) {}

    function cumulativeWithdrawalsQueued(address /*staker*/) external pure returns (uint256) {}

    function calculateWithdrawalRoot(Withdrawal memory /*withdrawal*/) external pure returns (bytes32) {}

    function getOperatorShares(
        address /*operator*/,
        IStrategy[] memory /*strategies*/
    ) external view returns (uint256[] memory) {}

    function getWithdrawalDelay(IStrategy[] calldata /*strategies*/) external view returns (uint256) {}

    function minWithdrawalDelayBlocks() external view returns (uint256) {}
    
    function strategyWithdrawalDelayBlocks(IStrategy /*strategy*/) external view returns (uint256) {}
    
    function beaconChainETHStrategy() external view returns (IStrategy) {}
}
