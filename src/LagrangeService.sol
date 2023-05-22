// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ISlasher} from "eigenlayer-contracts/interfaces/ISlasher.sol";

contract LagrangeService is Ownable {
    ISlasher public immutable slasher;

    struct Evidence {
        address operator;
        bytes32 blockHash;
        bytes32 correctBlockHash;
        bytes32 currentCommitteeRoot;
        bytes32 correctCurrentCommitteeRoot;
        bytes32 nextCommitteeRoot;
        bytes32 correctNextCommitteeRoot;
        uint256 blockNumber;
        uint256 epochNumber;
        bytes blockSignature; // 96-byte
        bytes commitSignature; // 96-byte
        uint32 chainID;
    }

    struct OperatorStatus {
        uint256 amount;
        uint32 serveUntilBlock;
        bool slashed;
    }

    mapping(address => OperatorStatus) public operators;

    uint32 public taskNumber = 0;
    uint32 public latestServeUntilBlock = 0;

    event OperatorRegistered(address operator, uint32 serveUntilBlock);
    event UploadEvidence(
        address operator,
        bytes32 blockHash,
        bytes32 currentCommitteeRoot,
        bytes32 nextCommitteeRoot,
        uint256 blockNumber,
        uint256 epochNumber,
        bytes blockSignature,
        bytes commitSignature,
        uint32 chainID
    );
    event OperatorSlashed(address operator);

    constructor(ISlasher _slasher) {
        slasher = _slasher;
    }

    function owner() public view override(Ownable) returns (address) {
        return Ownable.owner();
    }

    /// Add the operator to the service.
    function register(uint32 serveUntilBlock) external {
        _recordFirstStakeUpdate(msg.sender, serveUntilBlock);
        operators[msg.sender] = OperatorStatus({
            amount: 1, // TODO: get the voting power from the EigenLayer contract
            serveUntilBlock: serveUntilBlock,
            slashed: false
        });

        emit OperatorRegistered(msg.sender, serveUntilBlock);
    }

    /// upload the evidence to punish the operator.
    function uploadEvidence(Evidence calldata evidence) external {
        // check the operator is registered or not
        require(
            operators[evidence.operator].serveUntilBlock > 0,
            "The operator is not registered"
        );

        // check the operator is slashed or not
        require(
            !operators[evidence.operator].slashed,
            "The operator is slashed"
        );

        // require(_checkCommitSignature(evidence.operator, evidence.commitSignature, evidence.blockHash, evidence.stateRoot, evidence.currentCommitteeRoot, evidence.nextCommitteeRoot, evidence.blockNumber, evidence.chainID, evidence.commitSignature), "The commit signature is not correct");

        // if (_checkBlockSignature(evidence.operator, evidence.commitSignature, evidence.blockHash, evidence.stateRoot, evidence.currentCommitteeRoot, evidence.nextCommitteeRoot, evidence.chainID, evidence.commitSignature)) {
        //     _freezeOperator(evidence.operator);
        // }

        // if (_checkBlockHash(evidence.correctBlockHash, evidence.blockHash, evidence.blockNumber)) {
        //     _freezeOperator(evidence.operator);
        // }

        // if (_checkCurrentCommitteeRoot(evidence.correctCurrentCommitteeRoot, evidence.currentCommitteeRoot, evidence.epochNumber)) {
        //     _freezeOperator(evidence.operator);
        // }

        // if (_checkNextCommitteeRoot(evidence.correctNextCommitteeRoot, evidence.nextCommitteeRoot, evidence.epochNumber)) {
        //     _freezeOperator(evidence.operator);
        // }

        _freezeOperator(evidence.operator);

        emit UploadEvidence(
            evidence.operator,
            evidence.blockHash,
            evidence.currentCommitteeRoot,
            evidence.nextCommitteeRoot,
            evidence.blockNumber,
            evidence.epochNumber,
            evidence.blockSignature,
            evidence.commitSignature,
            evidence.chainID
        );
    }

    /// slash the given operator
    function _freezeOperator(address operator) internal {
        slasher.freezeOperator(operator);
        operators[operator].slashed = true;

        emit OperatorSlashed(operator);
    }

    function isFrozen(address operator) public view returns (bool) {
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
