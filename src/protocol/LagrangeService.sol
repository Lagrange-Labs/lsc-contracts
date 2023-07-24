// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {IServiceManager} from "eigenlayer-contracts/interfaces/IServiceManager.sol";
import {IStrategyManager} from "eigenlayer-contracts/interfaces/IStrategyManager.sol";
import {VoteWeigherBase} from "eigenlayer-contracts/middleware/VoteWeigherBase.sol";

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "../interfaces/ILagrangeCommittee.sol";
import "../interfaces/ILagrangeService.sol";

import {Common} from "../library/Common.sol";
import {EvidenceVerifier} from "../library/EvidenceVerifier.sol";

contract LagrangeService is
    Initializable,
    OwnableUpgradeable,
    ILagrangeService,
    EvidenceVerifier,
    VoteWeigherBase
{
    ILagrangeCommittee public immutable committee;

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

    constructor(
        IServiceManager _serviceManager,
        ILagrangeCommittee _committee,
        IStrategyManager _strategyManager
    ) VoteWeigherBase(_strategyManager, _serviceManager, 5) {
        committee = _committee;
        _disableInitializers();
    }

    function initialize(address initialOwner) external initializer {
        _transferOwnership(initialOwner);
    }

    /// Add the operator to the service.
    // Only unfractinalized WETH strategy shares assumed for stake amount
    function register(
        uint256 chainID,
        bytes memory _blsPubKey,
        uint32 serveUntilBlock
    ) external {
        uint96 stakeAmount = weightOfOperator(msg.sender, 1);
        require(stakeAmount > 0, "The stake amount is zero");

        serviceManager.recordFirstStakeUpdate(msg.sender, serveUntilBlock);
        committee.addOperator(
            msg.sender,
            chainID,
            _blsPubKey,
            stakeAmount,
            serveUntilBlock
        );

        emit OperatorRegistered(msg.sender, serveUntilBlock);
    }

    /// upload the evidence to punish the operator.
    function uploadEvidence(Evidence calldata evidence) external {
        // check the operator is registered or not
        require(
            committee.getServeUntilBlock(evidence.operator) > 0,
            "The operator is not registered"
        );

        // check the operator is slashed or not
        require(
            !committee.getSlashed(evidence.operator),
            "The operator is slashed"
        );

        require(
            checkCommitSignature(evidence),
            "The commit signature is not correct"
        );

        // if (!_checkBlockSignature(evidence.operator, evidence.commitSignature, evidence.blockHash, evidence.stateRoot, evidence.currentCommitteeRoot, evidence.nextCommitteeRoot, evidence.chainID, evidence.commitSignature)) {
        //     _freezeOperator(evidence.operator);
        // }

        if (
            !_checkBlockHash(
                evidence.correctBlockHash,
                evidence.blockHash,
                evidence.blockNumber,
                evidence.rawBlockHeader,
                evidence.chainID
            )
        ) {
            _freezeOperator(evidence.operator, evidence.chainID);
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
            _freezeOperator(evidence.operator, evidence.chainID);
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
            evidence.chainID
        );
    }

    // Slashing condition.  Returns veriifcation of block hash and number for a given chain.
    function _checkBlockHash(
        bytes32 correctBlockHash,
        bytes32 blockHash,
        uint256 blockNumber,
        bytes memory rawBlockHeader,
        uint256 chainID
    ) internal pure returns (bool) {
        return
            verifyBlockNumber(
                blockNumber,
                rawBlockHeader,
                correctBlockHash,
                chainID
            ) && blockHash == correctBlockHash;
    }

    function verifyRawHeaderSequence(bytes32 latestHash, bytes[] calldata sequence) public view returns (bool) {
        return _verifyRawHeaderSequence(latestHash, sequence);
    }

    // Slashing condition.  Returns veriifcation of chain's current committee root at a given block.
    function _checkCommitteeRoots(
        bytes32 correctCurrentCommitteeRoot,
        bytes32 currentCommitteeRoot,
        bytes32 correctNextCommitteeRoot,
        bytes32 nextCommitteeRoot,
        uint256 blockNumber,
        uint256 chainID
    ) internal returns (bool) {
        (
            ILagrangeCommittee.CommitteeData memory currentCommittee,
            uint256 nextRoot
        ) = committee.getCommittee(chainID, blockNumber);
        require(
            correctCurrentCommitteeRoot == bytes32(currentCommittee.root),
            "Reference current committee roots do not match."
        );
        require(
            correctNextCommitteeRoot == bytes32(nextRoot),
            "Reference next committee roots do not match."
        );

        return
            (currentCommitteeRoot == correctCurrentCommitteeRoot) &&
            (nextCommitteeRoot == correctNextCommitteeRoot);
    }

    /// Slash the given operator
    function _freezeOperator(address operator, uint256 chainID) internal {
        serviceManager.freezeOperator(operator);
        committee.setSlashed(operator, chainID, true);

        emit OperatorSlashed(operator);
    }

    function owner()
        public
        view
        override(OwnableUpgradeable, ILagrangeService)
        returns (address)
    {
        return OwnableUpgradeable.owner();
    }
}
