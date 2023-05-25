// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ISlasher} from "eigenlayer-contracts/interfaces/ISlasher.sol";
import {IStrategyManager} from "eigenlayer-contracts/interfaces/IStrategyManager.sol";
import {IStrategy} from "eigenlayer-contracts/interfaces/IStrategyManager.sol";
import {IServiceManager} from "eigenlayer-contracts/interfaces/IServiceManager.sol";

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "../../interfaces/LagrangeCommittee/ILagrangeCommittee.sol";

contract LagrangeService is Ownable, Initializable {
    ISlasher public immutable slasher;
    
    // NodeStaking Imports
    ILagrangeCommittee public LGRCommittee;
    
    // Service Mgr
    IServiceManager public ELServiceMgr;
    
    IStrategy WETHStrategy;

    function initialize(
      ILagrangeCommittee _lgrCommittee,
      IServiceManager _ELServiceMgr,
      IStrategy _WETHStrategy
    ) initializer public {
        LGRCommittee = _lgrCommittee;
        ELServiceMgr = _ELServiceMgr;
        WETHStrategy = _WETHStrategy;
        //__Ownable_init();
    }    
    // End NodeStaking Imports

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
        bytes rawBlockHeader;
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
        
//        ([]IStrategy memory strats, uint256[] shares) = ELServiceMgr.depositor(msg.sender);
//        uint256 amount = strats[WETHStrategy];
        
        operators[msg.sender] = OperatorStatus({
            amount: 0,//amount,
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

        // if (!_checkBlockSignature(evidence.operator, evidence.commitSignature, evidence.blockHash, evidence.stateRoot, evidence.currentCommitteeRoot, evidence.nextCommitteeRoot, evidence.chainID, evidence.commitSignature)) {
        //     _freezeOperator(evidence.operator);
        // }

        if (!_checkBlockHash(evidence.correctBlockHash, evidence.blockHash, evidence.blockNumber, evidence.rawBlockHeader, evidence.chainID)) {
            _freezeOperator(evidence.operator);
        }

        if (!_checkCurrentCommitteeRoot(evidence.correctCurrentCommitteeRoot, evidence.currentCommitteeRoot, evidence.epochNumber, evidence.chainID)) {
            _freezeOperator(evidence.operator);
        }

        if (!_checkNextCommitteeRoot(evidence.correctNextCommitteeRoot, evidence.nextCommitteeRoot, evidence.epochNumber, evidence.chainID)) {
            _freezeOperator(evidence.operator);
        }

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
    
    function _checkBlockHash(bytes32 correctBlockHash, bytes32 blockHash, uint256 blockNumber, bytes memory rawBlockHeader, uint256 chainID) internal view returns (bool) {
        return LGRCommittee.verifyBlockNumber(blockNumber, rawBlockHeader, correctBlockHash, chainID) && blockHash == correctBlockHash;
    }
    
    function _checkCurrentCommitteeRoot(bytes32 correctCurrentCommitteeRoot, bytes32 currentCommitteeRoot, uint256 epochNumber, uint256 chainID) internal view returns (bool) {
        bytes32 realCurrentCommitteeRoot = LGRCommittee.getCommitteeRoot(chainID, epochNumber);
        require(correctCurrentCommitteeRoot == realCurrentCommitteeRoot, "Reference committee roots do not match.");
        return currentCommitteeRoot == realCurrentCommitteeRoot;
    }

    function _checkNextCommitteeRoot(bytes32 correctNextCommitteeRoot, bytes32 nextCommitteeRoot, uint256 epochNumber, uint256 chainID) internal view returns (bool) {
        bytes32 realNextCommitteeRoot = LGRCommittee.getNextCommitteeRoot(chainID, epochNumber + 1);
        require(correctNextCommitteeRoot == realNextCommitteeRoot, "Reference committee roots do not match.");
        return nextCommitteeRoot == realNextCommitteeRoot;
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
