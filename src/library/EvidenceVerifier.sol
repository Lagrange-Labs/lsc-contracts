// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract EvidenceVerifier {
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
        uint256 epochNumber;
        bytes blockSignature; // 96-byte
        bytes commitSignature; // 65-byte
        uint32 chainID;
    }

    // check the evidence identity and the ECDSA signature
    function checkCommitSignature(Evidence calldata evidence) public pure returns (bool) {
        bytes32 commitHash = getCommitHash(evidence);
        address recoveredAddress = ECDSA.recover(commitHash, evidence.commitSignature);
        return recoveredAddress == evidence.operator;
    }

    // get the hash of the commit request
    function getCommitHash(Evidence calldata evidence) public pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    evidence.blockHash,
                    evidence.currentCommitteeRoot,
                    evidence.nextCommitteeRoot,
                    evidence.blockNumber,
                    evidence.epochNumber,
                    evidence.blockSignature,
                    evidence.chainID
                )
            );
    }
}
