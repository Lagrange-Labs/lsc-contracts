// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IStrategyManager} from "eigenlayer-contracts/interfaces/IStrategyManager.sol";
import {IStrategy} from "eigenlayer-contracts/interfaces/IStrategyManager.sol";
import {IServiceManager} from "eigenlayer-contracts/interfaces/IServiceManager.sol";

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "../interfaces/ILagrangeCommittee.sol";
import "../protocol/LagrangeServiceManager.sol";

import {EvidenceVerifier} from "../library/EvidenceVerifier.sol";

contract LagrangeService is EvidenceVerifier, Ownable, Initializable {
    mapping(address => bool) sequencers;
    
    IServiceManager public LGRServiceMgr;
    IStrategyManager public StrategyMgr;
    IStrategy public WETHStrategy;
    
    ILagrangeCommittee public LGRCommittee;
    
    uint32 public taskNumber = 0;
    uint32 public latestServeUntilBlock = 0;

    event OperatorRegistered(address operator, uint32 serveUntilBlock);
    
    event OperatorSlashed(address operator);

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
    
    function addSequencer(address seqAddr) public onlyOwner {
        sequencers[seqAddr] = true;
    }

    function removeSequencer(address seqAddr) public onlyOwner {
        sequencers[seqAddr] = false;
    }
    
    modifier onlySequencer() {
        require(sequencers[msg.sender] == true, "Only sequencer nodes can call this function.");
        _;
    }

    constructor(IServiceManager _LGRServiceMgr, ILagrangeCommittee _LGRCommittee, IStrategyManager _StrategyMgr, IStrategy _WETHStrategy) initializer {
        LGRServiceMgr = _LGRServiceMgr;
        LGRCommittee = _LGRCommittee;
        StrategyMgr = _StrategyMgr;
        WETHStrategy = _WETHStrategy;
    }

    /// Add the operator to the service.
    function register(uint256 chainID, uint256 stake, bytes memory _blsPubKey, uint32 serveUntilBlock) external {
        LGRServiceMgr.recordFirstStakeUpdate(msg.sender, serveUntilBlock);
        
//        ([]IStrategy memory strats, uint256[] shares) = ELServiceMgr.depositor(msg.sender);
//        uint256 amount = strats[WETHStrategy];
        
	LGRCommittee.add(chainID, _blsPubKey, stake, serveUntilBlock);

        emit OperatorRegistered(msg.sender, serveUntilBlock);
    }

    /// upload the evidence to punish the operator.
    function uploadEvidence(Evidence calldata evidence) external onlySequencer {
        // check the operator is registered or not
        require(
            LGRCommittee.getServeUntilBlock(evidence.operator) > 0,
            "The operator is not registered"
        );

        // check the operator is slashed or not
        require(
            !LGRCommittee.getSlashed(evidence.operator),
            "The operator is slashed"
        );

        require(
            checkCommitSignature(evidence),
            "The commit signature is not correct"
        );

        // if (!_checkBlockSignature(evidence.operator, evidence.commitSignature, evidence.blockHash, evidence.stateRoot, evidence.currentCommitteeRoot, evidence.nextCommitteeRoot, evidence.chainID, evidence.commitSignature)) {
        //     _freezeOperator(evidence.operator);
        // }

        if (!_checkBlockHash(evidence.correctBlockHash, evidence.blockHash, evidence.blockNumber, evidence.rawBlockHeader, evidence.chainID)) {
            _freezeOperator(evidence.operator,evidence.chainID);
        }

        if (!_checkCurrentCommitteeRoot(evidence.correctCurrentCommitteeRoot, evidence.currentCommitteeRoot, evidence.epochNumber, evidence.chainID)) {
            _freezeOperator(evidence.operator,evidence.chainID);
        }

        if (!_checkNextCommitteeRoot(evidence.correctNextCommitteeRoot, evidence.nextCommitteeRoot, evidence.epochNumber, evidence.chainID)) {
            _freezeOperator(evidence.operator,evidence.chainID);
        }

        //_freezeOperator(evidence.operator,evidence.chainID); // TODO what is this for (no condition)?

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
    
    function _checkBlockHash(bytes32 correctBlockHash, bytes32 blockHash, uint256 blockNumber, bytes memory rawBlockHeader, uint256 chainID) internal returns (bool) {
        return LGRCommittee.verifyBlockNumber(blockNumber, rawBlockHeader, correctBlockHash, chainID) && blockHash == correctBlockHash;
    }
    
    function _checkCurrentCommitteeRoot(bytes32 correctCurrentCommitteeRoot, bytes32 currentCommitteeRoot, uint256 epochNumber, uint256 chainID) internal returns (bool) {
        bytes32 realCurrentCommitteeRoot = bytes32(LGRCommittee.getCommittee(chainID, epochNumber));
        require(correctCurrentCommitteeRoot == realCurrentCommitteeRoot, "Reference committee roots do not match.");
        return currentCommitteeRoot == realCurrentCommitteeRoot;
    }

    function _checkNextCommitteeRoot(bytes32 correctNextCommitteeRoot, bytes32 nextCommitteeRoot, uint256 epochNumber, uint256 chainID) internal returns (bool) {
        bytes32 realNextCommitteeRoot = bytes32(LGRCommittee.getCommittee(chainID, epochNumber+1));
        require(correctNextCommitteeRoot == realNextCommitteeRoot, "Reference committee roots do not match.");
        return nextCommitteeRoot == realNextCommitteeRoot;
    }

    /// slash the given operator
    function _freezeOperator(address operator, uint256 chainID) internal onlySequencer {
        LGRServiceMgr.freezeOperator(operator);
        LGRCommittee.setSlashed(operator,true);
        LGRCommittee.remove(chainID, operator);

        emit OperatorSlashed(operator);
    }

/*
    function _isFrozen(address operator) public view returns (bool) {
        return LGRServiceManager.isFrozen(operator);
    }
*/

    function owner() public view override(Ownable) returns (address) {
        return Ownable.owner();
    }
}

