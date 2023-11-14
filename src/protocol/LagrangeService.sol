// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";

import {IServiceManager} from "../interfaces/IServiceManager.sol";
import {ILagrangeCommittee, OperatorStatus} from "../interfaces/ILagrangeCommittee.sol";
import {ILagrangeService} from "../interfaces/ILagrangeService.sol";

import {EvidenceVerifier} from "../library/EvidenceVerifier.sol";
import {ISlashingAggregateVerifierTriage} from "../interfaces/ISlashingAggregateVerifierTriage.sol";

contract LagrangeService is Initializable, OwnableUpgradeable, ILagrangeService {
    uint256 public constant UPDATE_TYPE_REGISTER = 1;
    uint256 public constant UPDATE_TYPE_AMOUNT_CHANGE = 2;
    uint256 public constant UPDATE_TYPE_UNREGISTER = 3;

    ILagrangeCommittee public immutable committee;
    IServiceManager public immutable serviceManager;

    ISlashingAggregateVerifierTriage AggVerify;
    EvidenceVerifier public evidenceVerifier;

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
        ISlashingAggregateVerifierTriage _AggVerify,
        EvidenceVerifier _evidenceVerifier
    ) external initializer {
        _transferOwnership(initialOwner);
        AggVerify = _AggVerify;
        evidenceVerifier = _evidenceVerifier;
    }

    /// Add the operator to the service.
    function register(bytes memory _blsPubKey, uint32 serveUntilBlock) external {
        require(_blsPubKey.length == 96, "LagrangeService: Inappropriately preformatted BLS public key.");

        committee.addOperator(msg.sender, _blsPubKey, serveUntilBlock);

        serviceManager.recordFirstStakeUpdate(msg.sender, serveUntilBlock);

        emit OperatorRegistered(msg.sender, serveUntilBlock);
    }

    /// Subscribe the dedicated chain.
    function subscribe(uint32 chainID) external {
        committee.subscribeChain(msg.sender, chainID);
    }

    function unsubscribe(uint32 chainID) external {
        committee.unsubscribeChain(msg.sender, chainID);
    }

    /// deregister the operator from the service.
    function deregister() external {
        (bool possible, uint256 unsubscribeBlockNumber) = committee.isUnregisterable(msg.sender);
        require(possible, "The operator is not able to deregister");
        serviceManager.recordLastStakeUpdateAndRevokeSlashingAbility(msg.sender, uint32(unsubscribeBlockNumber));
    }

    /// upload the evidence to punish the operator.
    function uploadEvidence(EvidenceVerifier.Evidence calldata evidence) external {
        // check the operator is registered or not
        require(committee.getServeUntilBlock(evidence.operator) > 0, "The operator is not registered");

        // check the operator is slashed or not
        require(!committee.getSlashed(evidence.operator), "The operator is slashed");

        require(evidenceVerifier.checkCommitSignature(evidence), "The commit signature is not correct");

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

        // TODO what is this for (no condition)?

        emit UploadEvidence(
            evidence.operator,
            evidence.blockHash,
            evidence.currentCommitteeRoot,
            evidence.nextCommitteeRoot,
            evidence.blockNumber,
            evidence.epochBlockNumber,
            evidence.blockSignature,
            evidence.commitSignature,
            evidence.chainID
        );
    }

    function _checkBlockSignature(EvidenceVerifier.Evidence memory _evidence) internal returns (bool) {
        // establish that proofs are valid
        (ILagrangeCommittee.CommitteeData memory cdata,) =
            committee.getCommittee(_evidence.chainID, _evidence.blockNumber);

        require(
            AggVerify.verify(
                _evidence.aggProof,
                _evidence.currentCommitteeRoot,
                _evidence.nextCommitteeRoot,
                _evidence.blockHash,
                _evidence.blockNumber,
                _evidence.chainID,
                cdata.height
            ),
            "Aggregate proof verification failed"
        );

        bytes memory blsPubKey = committee.getBlsPubKey(_evidence.operator);
        bool sigVerify = evidenceVerifier.verifySingle(_evidence, blsPubKey);

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
        serviceManager.freezeOperator(operator);

        emit OperatorSlashed(operator);
    }

    function owner() public view override(OwnableUpgradeable, ILagrangeService) returns (address) {
        return OwnableUpgradeable.owner();
    }
}
