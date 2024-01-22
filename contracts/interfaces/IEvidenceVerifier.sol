// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

// Evidence is the data structure to store the slashing evidence.
struct Evidence {
    address operator;
    bytes32 blockHash;
    bytes32 correctBlockHash;
    bytes32 currentCommitteeRoot;
    bytes32 correctCurrentCommitteeRoot;
    bytes32 nextCommitteeRoot;
    bytes32 correctNextCommitteeRoot;
    uint256 blockNumber;
    uint256 l1BlockNumber;
    bytes blockSignature; // 192-byte
    bytes commitSignature; // 65-byte
    uint32 chainID;
    bytes sigProof;
    bytes aggProof;
}

// ProofParams is the proof parameters for the BLS signature verification.
struct ProofParams {
    uint256[2] a;
    uint256[2][2] b;
    uint256[2] c;
}

// Path: contracts/interfaces/IEvidenceVerifier.sol
interface IEvidenceVerifier {
    function setAggregateVerifierRoute(uint256 routeIndex, address _verifierAddress) external;
    function setSingleVerifier(address _verifierAddress) external;
    function uploadEvidence(Evidence calldata evidence) external;
}
