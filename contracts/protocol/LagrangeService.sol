// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

import {IStakeManager} from "../interfaces/IStakeManager.sol";
import {ILagrangeCommittee} from "../interfaces/ILagrangeCommittee.sol";
import {ILagrangeService} from "../interfaces/ILagrangeService.sol";

contract LagrangeService is Initializable, OwnableUpgradeable, ILagrangeService {
    mapping(address => bool) public operatorWhitelist;

    ILagrangeCommittee public immutable committee;
    IStakeManager public immutable stakeManager;

    event OperatorRegistered(address operator, uint32 serveUntilBlock);
    event OperatorDeregistered(address operator);
    event OperatorSubscribed(address operator, uint32 chainID);
    event OperatorUnsubscribed(address operator, uint32 chainID);

    modifier onlyWhitelisted() {
        require(operatorWhitelist[msg.sender], "Operator is not whitelisted");
        _;
    }

    constructor(ILagrangeCommittee _committee, IStakeManager _stakeManager) {
        committee = _committee;
        stakeManager = _stakeManager;
        _disableInitializers();
    }

    function initialize(address initialOwner) external initializer {
        _transferOwnership(initialOwner);
    }

    /// Add the operator to the whitelist.
    function addOperatorsToWhitelist(address[] calldata operators) external onlyOwner {
        for (uint256 i = 0; i < operators.length; i++) {
            operatorWhitelist[operators[i]] = true;
        }
    }

    /// Remove the operator from the whitelist.
    function removeOperatorsFromWhitelist(address[] calldata operators) external onlyOwner {
        for (uint256 i = 0; i < operators.length; i++) {
            delete operatorWhitelist[operators[i]];
        }
    }

    /// Add the operator to the service.
    function register(uint256[2][] memory blsPubKeys) external onlyWhitelisted {
        committee.addOperator(msg.sender, blsPubKeys);
        uint32 serveUntilBlock = type(uint32).max;
        stakeManager.lockStakeUntil(msg.sender, serveUntilBlock);
        emit OperatorRegistered(msg.sender, serveUntilBlock);
    }

    /// Add extra BlsPubKeys
    function addBlsPubKeys(uint256[2][] memory additionalBlsPubKeys) external onlyWhitelisted {
        committee.addBlsPubKeys(msg.sender, additionalBlsPubKeys);
        uint32 serveUntilBlock = type(uint32).max;
        stakeManager.lockStakeUntil(msg.sender, serveUntilBlock);
        emit OperatorRegistered(msg.sender, serveUntilBlock);
    }

    /// Subscribe the dedicated chain.
    function subscribe(uint32 chainID) external onlyWhitelisted {
        committee.subscribeChain(msg.sender, chainID);
        emit OperatorSubscribed(msg.sender, chainID);
    }

    /// Unsubscribe the dedicated chain.
    function unsubscribe(uint32 chainID) external onlyWhitelisted {
        committee.unsubscribeChain(msg.sender, chainID);
        emit OperatorUnsubscribed(msg.sender, chainID);
    }

    /// Deregister the operator from the service.
    function deregister() external onlyWhitelisted {
        (bool possible, uint256 unsubscribeBlockNumber) = committee.isUnregisterable(msg.sender);
        require(possible, "The operator is not able to deregister");
        stakeManager.lockStakeUntil(msg.sender, unsubscribeBlockNumber);
        emit OperatorDeregistered(msg.sender);
    }

    function owner() public view override(OwnableUpgradeable, ILagrangeService) returns (address) {
        return OwnableUpgradeable.owner();
    }
}
