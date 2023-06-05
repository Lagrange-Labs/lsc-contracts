// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";

import {ISlasher} from "eigenlayer-contracts/interfaces/ISlasher.sol";
//import {IStrategyManager} from "eigenlayer-contracts/interfaces/IStrategyManager.sol";
//import {IStrategy} from "eigenlayer-contracts/interfaces/IStrategyManager.sol";
import {IServiceManager} from "eigenlayer-contracts/interfaces/IServiceManager.sol";

//import "../interfaces/ILagrangeCommittee.sol";

contract LagrangeServiceManager is Ownable, Initializable, IServiceManager {
    ISlasher public immutable slasher;

    constructor(ISlasher _slasher) {
        slasher = _slasher;
    }
    
/////
    uint32 public taskNumber = 0;

    // slash the given operator
    function freezeOperator(address operator) external {
        slasher.freezeOperator(operator);
    }

    function recordFirstStakeUpdate(
        address operator,
        uint32 serveUntilBlock
    ) external {
        slasher.recordFirstStakeUpdate(operator, serveUntilBlock);
    }

    function recordStakeUpdate(
        address operator,
        uint32 updateBlock,
        uint32 serveUntilBlock,
        uint256 prevElement
    ) external {
        slasher.recordStakeUpdate(
            operator,
            updateBlock,
            serveUntilBlock,
            prevElement
        );
    }

    function recordLastStakeUpdateAndRevokeSlashingAbility(
        address operator,
        uint32 serveUntilBlock
    ) external {
        slasher.recordLastStakeUpdateAndRevokeSlashingAbility(
            operator,
            serveUntilBlock
        );
    }

    uint32 public latestServeUntilBlock = 0;

    function owner() public view override(Ownable, IServiceManager) returns (address) {
        return Ownable.owner();
    }
    /////
}
