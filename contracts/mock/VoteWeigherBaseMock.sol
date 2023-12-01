// SPDX-License-Identifier: MIT

/* eslint-disable */
// forgefmt: disable-start

pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";

import {IStrategyManager} from "eigenlayer-contracts/src/contracts/interfaces/IStrategyManager.sol";
import {IServiceManager} from "eigenlayer-middleware/interfaces/IServiceManager.sol";
import {VoteWeigherBase} from "eigenlayer-middleware/VoteWeigherBase.sol";

contract VoteWeigherBaseMock is Initializable, OwnableUpgradeable, VoteWeigherBase {
    constructor(IServiceManager _serviceManager, IStrategyManager _strategyManager)
        VoteWeigherBase(_strategyManager, _serviceManager)
    {
        _disableInitializers();
    }

    function initialize(address initialOwner) external initializer {
        _transferOwnership(initialOwner);
    }
}
