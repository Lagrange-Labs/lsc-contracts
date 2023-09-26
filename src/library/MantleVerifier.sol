// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import {Common} from "./Common.sol";
import {IRecursiveHeaderVerifier} from "../interfaces/IRecursiveHeaderVerifier.sol";
import {IMantleVerifier} from "../interfaces/IMantleVerifier.sol";
import {IAssertionMap} from "../mock/mantle/IAssertionMap.sol";
import "solidity-rlp/contracts/Helper.sol";

contract MantleVerifier is Common, IMantleVerifier {
    using RLPReader for RLPReader.RLPItem;
    using RLPReader for RLPReader.Iterator;
    using RLPReader for bytes;

    IAssertionMap public Assertions;

    constructor(IAssertionMap _assertions) {
        Assertions = _assertions;
    }

    struct AssertionSummary {
        uint256 assertionID;
        bytes32 root;
	uint256 l2blocknum;
    }
    
    function verifyMntBlock(
        bytes calldata rlpData,
        bytes32 attestHash,
        bytes calldata checkpointRLP,
        bytes calldata headerProof,
        bytes calldata extraData, // bytes32+uint256
        IRecursiveHeaderVerifier RHVerify
    ) public view returns (bool) {
        // 0. Construct proofs offchain
        
        // 1. Parse RLP
	(bytes32 stateRoot, uint256 blockNumber) = _parseRootAndBlock(checkpointRLP);

        // 2. Verify assertion summary and checkpoint RLP against mantle contracts
	AssertionSummary memory proof = abi.decode(extraData,(AssertionSummary));

	require(Assertions.getInboxSize(proof.assertionID) == proof.l2blocknum, "MantleVerifier: L2 block number doesn't match");
	require(Assertions.getStateHash(proof.assertionID) == proof.root, "MantleVerifier: State root doesn't match");
	require(stateRoot == proof.root, "MantleVerifier: State root doesn't match");
	require(blockNumber == proof.l2blocknum, "MantleVerifier: L2 block number doesn't match");
	
        // 4. Recursively verify attested hash in checkpoint block header
	return _verifyProof(RHVerify, rlpData, keccak256(checkpointRLP), headerProof);
    }

    function _parseRootAndBlock(bytes calldata checkpointRLP) internal view returns (bytes32, uint256) {
        RLPReader.RLPItem[] memory decoded = checkAndDecodeRLP(
            checkpointRLP,
            keccak256(checkpointRLP)
        );
	
	bytes32 stateRoot = bytes32(decoded[
            Common.BLOCK_HEADER_STATEROOT_INDEX
        ].toUint());

	uint256 blockNumber = uint256(decoded[
            Common.BLOCK_HEADER_NUMBER_INDEX
        ].toUint());
	return (stateRoot, blockNumber);
    }

    function _verifyProof(IRecursiveHeaderVerifier RHVerify, bytes calldata rlpData, bytes32 l2hash, bytes calldata headerProof) internal view returns (bool) {
        return RHVerify.verifyProof(rlpData, headerProof, l2hash);
    }
}
