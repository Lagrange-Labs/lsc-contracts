// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {IServiceManager} from "eigenlayer-contracts/interfaces/IServiceManager.sol";

import "@openzeppelin-upgrades/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin-upgrades/contracts/access/OwnableUpgradeable.sol";
import "../interfaces/ILagrangeCommittee.sol";
import "../interfaces/ILagrangeService.sol";

import {EvidenceVerifier} from "../library/EvidenceVerifier.sol";

contract LagrangeService is
    Initializable,
    OwnableUpgradeable,
    ILagrangeService,
    EvidenceVerifier
{
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

    constructor(
        ILagrangeCommittee _committee,
        IServiceManager _serviceManager
    ) {
        committee = _committee;
        serviceManager = _serviceManager;
        _disableInitializers();
    }

    function initialize(address initialOwner) external initializer {
        _transferOwnership(initialOwner);
    }

    /// Add the operator to the service.
    // Only unfractinalized WETH strategy shares assumed for stake amount
    function register(
        uint32 chainID,
        bytes memory _blsPubKey,
        uint32 serveUntilBlock
    ) external {
        // NOTE: Please ensure that the order of the following two lines remains unchanged
        committee.addOperator(msg.sender, _blsPubKey, chainID, serveUntilBlock);
        serviceManager.recordFirstStakeUpdate(msg.sender, serveUntilBlock);

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

       if (!_checkBlockSignature(evidence)) {
           _freezeOperator(evidence.operator);
       }
       
       if (
            !_checkBlockHash(
                evidence.correctBlockHash,
                evidence.blockHash,
                evidence.blockNumber,
                evidence.attestBlockHeader,
                evidence.chainID
            )
        ) {
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
        /*
        address operator,
        bytes   calldata blockSignature,
        bytes32 blockHash,
        bytes32 currentCommitteeRoot,
        bytes32 nextCommitteeRoot,
        uint32 chainID,
        bytes   calldata commitSignature,
        bytes   calldata sigProof,
        bytes   calldata aggProof
        */
    ) internal returns (bool) {
        (ILagrangeCommittee.CommitteeData memory cdata, uint256 next) = committee.getCommittee(_evidence.chainID, _evidence.blockNumber);
        (bool sigVerify, uint[75] memory svInput) = SigVerify.verify(_evidence.sigProof, cdata.height);
        (bool aggVerify, uint[5] memory avInput) = AggVerify.verify(_evidence.aggProof, cdata.height);
        // process input results
        
        return (sigVerify && aggVerify);
    }

    // Slashing condition.  Returns veriifcation of block hash and number for a given chain.
    function _checkBlockHash(
        bytes32 correctBlockHash,
        bytes32 blockHash,
        uint256 blockNumber,
        bytes calldata attestBlockHeader,
        uint256 chainID
    ) internal pure returns (bool) {
          return correctBlockHash == blockHash;
    /*
        return
            verifyBlockNumber(
                blockNumber,
                attestBlockHeader,
                correctBlockHash,
                chainID
            ) && blockHash == correctBlockHash;
    */
    }

    /*
    function verifyRawHeaderSequence(bytes32 latestHash, bytes[] calldata sequence) public view returns (bool) {
        return _verifyRawHeaderSequence(latestHash, sequence);
    }
*/
    // Slashing condition.  Returns veriifcation of chain's current committee root at a given block.
    function _checkCommitteeRoots(
        bytes32 correctCurrentCommitteeRoot,
        bytes32 currentCommitteeRoot,
        bytes32 correctNextCommitteeRoot,
        bytes32 nextCommitteeRoot,
        uint256 blockNumber,
        uint32 chainID
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
    function _freezeOperator(address operator) internal {
        committee.setSlashed(operator);
        serviceManager.freezeOperator(operator);

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
