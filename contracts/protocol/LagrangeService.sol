// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

import {IServiceManager} from "../interfaces/IServiceManager.sol";
import {ILagrangeCommittee, OperatorStatus} from "../interfaces/ILagrangeCommittee.sol";
import {ILagrangeService} from "../interfaces/ILagrangeService.sol";

contract LagrangeService is Initializable, OwnableUpgradeable, ILagrangeService {
    mapping(address => bool) public operatorWhitelist;

    ILagrangeCommittee public immutable committee;
    IServiceManager public immutable serviceManager;

    event OperatorRegistered(address operator, uint32 serveUntilBlock);
    event OperatorDeregistered(address operator);
    event OperatorSubscribed(address operator, uint32 chainID);
    event OperatorUnsubscribed(address operator, uint32 chainID);

    modifier onlyWhitelisted() {
        require(operatorWhitelist[msg.sender], "Operator is not whitelisted");
        _;
    }

    constructor(ILagrangeCommittee _committee, IServiceManager _serviceManager) {
        committee = _committee;
        serviceManager = _serviceManager;
        _disableInitializers();
    }

    function initialize(address initialOwner) external initializer {
        _transferOwnership(initialOwner);
    }

    /// Add the operator to the whitelist.
    function addOperatorToWhitelist(address operator) external onlyOwner {
        operatorWhitelist[operator] = true;
    }

    /// Remove the operator from the whitelist.
    function removeOperatorFromWhitelist(address operator) external onlyOwner {
        operatorWhitelist[operator] = false;
    }

    /// Add the operator to the service.
    function register(uint256[2] memory _blsPubKey, uint32 serveUntilBlock) external onlyWhitelisted {
        committee.addOperator(msg.sender, _blsPubKey, serveUntilBlock);
        serviceManager.recordFirstStakeUpdate(msg.sender, serveUntilBlock);
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
        serviceManager.recordLastStakeUpdateAndRevokeSlashingAbility(msg.sender, uint32(unsubscribeBlockNumber));
        emit OperatorDeregistered(msg.sender);
    }

    function owner() public view override(OwnableUpgradeable, ILagrangeService) returns (address) {
        return OwnableUpgradeable.owner();
    }
}
