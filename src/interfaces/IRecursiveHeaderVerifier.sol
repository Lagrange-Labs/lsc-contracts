// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IRecursiveHeaderVerifier {
    function verifyProof(
        bytes memory rawBlockHeader,
        bytes calldata proof,
        bytes32 checkpointBlockHash
    ) external view returns (bool);
}
