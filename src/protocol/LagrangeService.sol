// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

import {IServiceManager} from "../interfaces/IServiceManager.sol";
import {ILagrangeCommittee, OperatorStatus} from "../interfaces/ILagrangeCommittee.sol";
import {ILagrangeService} from "../interfaces/ILagrangeService.sol";

import {EvidenceVerifier} from "../library/EvidenceVerifier.sol";
import {ISlashingSingleVerifierTriage} from "../interfaces/ISlashingSingleVerifierTriage.sol";
import {ISlashingAggregateVerifierTriage} from "../interfaces/ISlashingAggregateVerifierTriage.sol";

contract LagrangeService is Initializable, OwnableUpgradeable, ILagrangeService, EvidenceVerifier {
    uint256 public constant UPDATE_TYPE_REGISTER = 1;
    uint256 public constant UPDATE_TYPE_AMOUNT_CHANGE = 2;
    uint256 public constant UPDATE_TYPE_UNREGISTER = 3;

    ILagrangeCommittee public immutable committee;
    IServiceManager public immutable serviceManager;

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

    constructor(ILagrangeCommittee _committee, IServiceManager _serviceManager) {
        committee = _committee;
        serviceManager = _serviceManager;
        _disableInitializers();
    }

    function initialize(
      address initialOwner,
      ISlashingSingleVerifierTriage _SigVerify,
      ISlashingAggregateVerifierTriage _AggVerify
    ) external initializer {
        _transferOwnership(initialOwner);
        SigVerify = _SigVerify;
        AggVerify = _AggVerify;
    }

    /// Add the operator to the service.
    // Only unfractinalized WETH strategy shares assumed for stake amount
    function register(uint32 chainID, bytes memory _blsPubKey, uint32 serveUntilBlock) external {
        // NOTE: Please ensure that the order of the following two lines remains unchanged
        (bool locked,) = committee.isLocked(chainID);
        require(!locked, "The related chain is in the freeze period");

        require(_blsPubKey.length == 96, "LagrangeService: Inappropriately preformatted BLS public key.");

        committee.addOperator(msg.sender, _blsPubKey, chainID, serveUntilBlock);
        serviceManager.recordFirstStakeUpdate(msg.sender, serveUntilBlock);

        emit OperatorRegistered(msg.sender, serveUntilBlock);
    }

    /// deregister the operator from the service.
    function deregister(uint32 chainID) external {
        (bool locked, uint256 epochEnd) = committee.isLocked(chainID);
        require(!locked, "The related chain is in the freeze period");

        serviceManager.recordLastStakeUpdateAndRevokeSlashingAbility(msg.sender, uint32(epochEnd));
    }

    /// upload the evidence to punish the operator.
    function uploadEvidence(Evidence calldata evidence) external {
        // check the operator is registered or not
        require(committee.getServeUntilBlock(evidence.operator) > 0, "The operator is not registered");

        // check the operator is slashed or not
        require(!committee.getSlashed(evidence.operator), "The operator is slashed");

        require(checkCommitSignature(evidence), "The commit signature is not correct");

       if (!_checkBlockSignature(evidence)) {
           _freezeOperator(evidence.operator);
       }
       
       if (evidence.correctBlockHash == evidence.blockHash) {
            _freezeOperator(evidence.operator);
        }

        if (
            !_checkCommitteeRoots(
                evidence.correctCurrentCommitteeRoot,
                evidence.currentCommitteeRoot,
                evidence.correctNextCommitteeRoot,
                evidence.nextCommitteeRoot,
                evidence.epochBlockNumber,
                evidence.chainID
            )
        ) {
            _freezeOperator(evidence.operator);
        }

        //_freezeOperator(evidence.operator,evidence.chainID); // TODO what is this for (no condition)?

        emit UploadEvidence(
            evidence.operator,
            evidence.blockHash,
            evidence.currentCommitteeRoot,
            evidence.nextCommitteeRoot,
            evidence.blockNumber,
            evidence.epochBlockNumber,
            evidence.blockSignature,
            evidence.commitSignature,
            evidence.chainID//,
            //evidence.sigProof,
            //evidence.aggProof
        );
    }

    function _checkBlockSignature(
        Evidence memory _evidence
    ) internal returns (bool) {
        OperatorStatus memory op = committee.getOperator(_evidence.operator);
        
        // establish that proofs are valid
        (ILagrangeCommittee.CommitteeData memory cdata, uint256 next) = committee.getCommittee(_evidence.chainID, _evidence.blockNumber);
        
        bool sigVerify = SigVerify.verify(
          _evidence,
          op.blsPubKey,
          cdata.height
        );
        
        bool aggVerify = AggVerify.verify(
          _evidence.aggProof,
          _evidence.currentCommitteeRoot,
          _evidence.nextCommitteeRoot,
          _evidence.blockHash,
          _evidence.blockNumber,
          _evidence.chainID,
          cdata.height
        );

        // compare signingroot to evidence, extract values - TODO crossreference/confirm
        bytes32 reconstructedSigningRoot = keccak256(abi.encodePacked(
            _evidence.currentCommitteeRoot,
            _evidence.nextCommitteeRoot,
            _evidence.blockNumber,
            _evidence.blockHash
        ));

        return (sigVerify);
    }
        
    // Slashing condition.  Returns veriifcation of chain's current committee root at a given block.
    function _checkCommitteeRoots(
        bytes32 correctCurrentCommitteeRoot,
        bytes32 currentCommitteeRoot,
        bytes32 correctNextCommitteeRoot,
        bytes32 nextCommitteeRoot,
        uint256 blockNumber,
        uint32 chainID
    ) internal returns (bool) {
        (ILagrangeCommittee.CommitteeData memory currentCommittee, uint256 nextRoot) =
            committee.getCommittee(chainID, blockNumber);
        require(
            correctCurrentCommitteeRoot == bytes32(currentCommittee.root),
            "Reference current committee roots do not match."
        );
        require(correctNextCommitteeRoot == bytes32(nextRoot), "Reference next committee roots do not match.");

        return (currentCommitteeRoot == correctCurrentCommitteeRoot) && (nextCommitteeRoot == correctNextCommitteeRoot);
    }

    /// Slash the given operator
    function _freezeOperator(address operator) internal {
        committee.setSlashed(operator);
        serviceManager.freezeOperator(operator);

        emit OperatorSlashed(operator);
    }

    function owner() public view override(OwnableUpgradeable, ILagrangeService) returns (address) {
        return OwnableUpgradeable.owner();
    }
}
