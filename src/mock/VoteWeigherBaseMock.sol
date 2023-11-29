// SPDX-License-Identifier: MIT

/* eslint-disable */
// forgefmt: disable-start

pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";

import {IStrategyManager} from "eigenlayer-contracts/src/contracts/interfaces/IStrategyManager.sol";
import {IServiceManager} from "src/interfaces/IServiceManager.sol";
import {VoteWeigherBase} from "eigenlayer-middleware/VoteWeigherBase.sol";

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
