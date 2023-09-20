// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Common} from "./Common.sol";
import {IRecursiveHeaderVerifier} from "../interfaces/IRecursiveHeaderVerifier.sol";
import {IMantleVerifier} from "../interfaces/IMantleVerifier.sol";
import {IStateCommitmentChain} from "../mock/mantle/IStateCommitmentChain.sol";
import {IChainStorageContainer} from "../mock/mantle/IChainStorageContainer.sol";
import {Lib_MerkleTree} from "../mock/mantle/Lib_MerkleTree.sol";

contract MantleVerifier is Common, IMantleVerifier {

    IStateCommitmentChain public SCChain;
    IChainStorageContainer public CSContainer;

    struct ChainInclusionProof {
        uint256 index;
        bytes32[] siblings;
    }
    
    // Must be computed offchain
    struct SCCPayload {
        // inclusion proof
        uint256 index;
        bytes32[] siblings;
        // merkle proof
        uint256 length;
        // batch header proof
        uint256 batchIndex;
        bytes32 batchRoot;
        uint256 batchSize;
        uint256 prevTotalElements;
        bytes signature;
        bytes extraData;        
    }
        
    constructor(IStateCommitmentChain _scc, IChainStorageContainer _csc) {
        SCChain = _scc;
        CSContainer = _csc;
    }
    
    function _verifyInclusion(bytes32 stateRoot, bytes calldata extraData) internal view returns (bool) {
        SCCPayload memory proof = abi.decode(extraData,(SCCPayload));
        return Lib_MerkleTree.verify(
            proof.batchRoot,
            stateRoot,
            proof.index,
            proof.siblings,
            proof.length
        );
    }

    function _verifyBatch(bytes calldata extraData) internal view returns (bool) {
        SCCPayload memory proof = abi.decode(extraData,(SCCPayload));
        bytes32 batch = CSContainer.get(proof.index);
        require(batch == keccak256(abi.encode(
            proof.batchRoot,
            proof.batchSize,
            proof.prevTotalElements,
            proof.signature,
            proof.extraData
        )), "Batch does not match header");
    }

    function verifyMntBlock(
        bytes calldata rlpData,
        bytes32 attestHash,
        bytes calldata checkpointRLP,
        bytes calldata headerProof,
        bytes calldata extraData, //SCCPayload
        IRecursiveHeaderVerifier RHVerify
    ) public view returns (bool) {
        // 0. Construct proofs offchain
        
        // 1. Parse RLP
        bytes32 stateRoot = _getBlockStateRoot(checkpointRLP, keccak256(checkpointRLP));
        
        // 2. Verify inclusion of checkpoint block's stateroot against provided proof
        require(_verifyInclusion(stateRoot, extraData), "Failed to verify checkpoint block inclusion.");
        
        // 3. Retrieve batch from StateCommitmentChain, verify proof provided against it
        bool res = _verifyBatch(extraData);

        // 4. Recursively verify attested hash in checkpoint block header
        bytes32 l2hash = keccak256(checkpointRLP);
        return RHVerify.verifyProof(rlpData, headerProof, l2hash);
    }
}
