// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ISlasher} from "eigenlayer-contracts/interfaces/ISlasher.sol";

contract LagrangeService is Ownable {
    ISlasher public immutable slasher;
    mapping(address=>uint32) public operators;

    uint32 public taskNumber = 0;
    uint32 public latestServeUntilBlock = 0;

    constructor(ISlasher _slasher) {
        slasher = _slasher;
    }

    function owner()
        public
        view
        override(Ownable)
        returns (address)
    {
        return Ownable.owner();
    }

    /// Add the operator to the service.
    function register(uint32 serveUntilBlock) external {
        _recordFirstStakeUpdate(msg.sender, serveUntilBlock);
        operators[msg.sender] = serveUntilBlock;
    }

    /// slash the given operator
    function freezeOperator(address operator) external onlyOwner{
        slasher.freezeOperator(operator);
        // TODO: integrate with evidences
    }
    
    function isFrozen(address operator) external view returns (bool) {
        return slasher.isFrozen(operator);
    }
    
    function _recordFirstStakeUpdate(
        address operator,
        uint32 serveUntilBlock
    ) internal {
        slasher.recordFirstStakeUpdate(operator, serveUntilBlock);
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
}
