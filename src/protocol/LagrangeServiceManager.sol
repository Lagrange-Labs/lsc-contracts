// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";

import {ISlasher} from "eigenlayer-contracts/interfaces/ISlasher.sol";
import {IServiceManager} from "eigenlayer-contracts/interfaces/IServiceManager.sol";

//import "../interfaces/ILagrangeCommittee.sol";

contract LagrangeServiceManager is
    Initializable,
    OwnableUpgradeable,
    IServiceManager
{
    ISlasher public immutable slasher;

    uint32 public taskNumber = 0;
    uint32 public latestServeUntilBlock = 0;

    constructor(ISlasher _slasher) {
        slasher = _slasher;
    }

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

    function owner() public view override(OwnableUpgradeable, IServiceManager) returns (address) {
        return OwnableUpgradeable.owner();
    }
}
