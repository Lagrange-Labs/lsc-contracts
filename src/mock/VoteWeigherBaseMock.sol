// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";

import {IStrategyManager} from "eigenlayer-contracts/interfaces/IStrategyManager.sol";
import {IServiceManager} from "eigenlayer-contracts/interfaces/IServiceManager.sol";
import {VoteWeigherBase} from "eigenlayer-contracts/middleware/VoteWeigherBase.sol";

contract VoteWeigherBaseMock is Initializable, OwnableUpgradeable, VoteWeigherBase {
    constructor(IServiceManager _serviceManager, IStrategyManager _strategyManager)
        VoteWeigherBase(_strategyManager, _serviceManager, 5)
    {
        _disableInitializers();
    }

    function initialize(address initialOwner) external initializer {
        _transferOwnership(initialOwner);
    }
}
