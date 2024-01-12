// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";

import {IServiceManager} from "../interfaces/IServiceManager.sol";
import {ILagrangeCommittee} from "../interfaces/ILagrangeCommittee.sol";
import {ILagrangeService} from "../interfaces/ILagrangeService.sol";
import {IStakeManager} from "../interfaces/IStakeManager.sol";

contract LagrangeServiceManager is Initializable, OwnableUpgradeable, IServiceManager {
    IStakeManager public immutable slasher;
    ILagrangeCommittee public immutable committee;
    ILagrangeService public immutable service;

    uint32 public taskNumber = 0;
    uint32 public latestServeUntilBlock = 0;

    modifier onlyService() {
        require(msg.sender == address(service), "Only Lagrange service can call this function.");
        _;
    }

    constructor(IStakeManager _slasher, ILagrangeCommittee _committee, ILagrangeService _service) {
        slasher = _slasher;
        committee = _committee;
        service = _service;
        _disableInitializers();
    }

    function initialize(address initialOwner) external initializer {
        _transferOwnership(initialOwner);
    }

    // slash the given operator
    function freezeOperator(address operator) external onlyService {
        committee.freezeOperator(operator);
        slasher.freezeOperator(operator);
    }

    function recordFirstStakeUpdate(address operator, uint32 serveUntilBlock) external onlyService {
        slasher.recordFirstStakeUpdate(operator, serveUntilBlock);
    }

    function recordStakeUpdate(address operator, uint32 updateBlock, uint32 serveUntilBlock, uint256 prevElement)
        external
    {
        committee.updateOperatorAmount(operator);
        slasher.recordStakeUpdate(operator, updateBlock, serveUntilBlock, prevElement);
    }

    function recordLastStakeUpdateAndRevokeSlashingAbility(address operator, uint32 serveUntilBlock)
        external
        onlyService
    {
        slasher.recordLastStakeUpdateAndRevokeSlashingAbility(operator, serveUntilBlock);
    }

    function owner() public view override(OwnableUpgradeable, IServiceManager) returns (address) {
        return OwnableUpgradeable.owner();
    }
}
